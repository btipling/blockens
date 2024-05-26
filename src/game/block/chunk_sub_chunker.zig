pos: chunk.sub_chunk.subPosition,
data: [chunk.sub_chunk.subChunkSize]subChunkVoxelData = undefined,
meshes: [chunk.sub_chunk.subChunkSize]shubChunkMesh = undefined,
num_meshes: usize = 0,
total_indices_count: usize = 0,
// these are used to generate vertices for each surface
positions: [36][3]u4,
indices: [36]u32,
normals: [36][3]u2,

// fixed buffer allocator
fba_buffer: [chunk.sub_chunk.subChunkSize * @sizeOf(@Vector(4, f32))]u8,
fba: std.heap.FixedBufferAllocator,
allocator: std.mem.Allocator,

// for quad finding, from old chunker
current_voxel: usize = 0,
num_voxels_in_mesh: usize = 0,
caching_meshed: bool = true,
current_scale: @Vector(4, u4) = .{ 0, 0, 0, 0 },
to_be_meshed: [min_voxels_in_mesh]usize = [_]usize{0} ** min_voxels_in_mesh,
meshed: [chunk.sub_chunk.subChunkSize]bool = [_]bool{false} ** chunk.sub_chunk.subChunkSize,
mesh_map: std.AutoHashMapUnmanaged(usize, @Vector(4, u4)) = .{},

const chunkerSubChunker = @This();

const min_voxels_in_mesh = 1;

pub const ChunkerError = error{
    NoMeshData,
};

pub const shubChunkMesh = struct {
    sub_index_pos: @Vector(4, u4),
    bd_id: u32,
    positions: [36][3]u4 = undefined,
    indices: [36]u32 = undefined,
    normals: [36][3]u2 = undefined,
};

pub const subChunkVoxelData = struct {
    bd_id: u32,
    scd: chunk.sub_chunk.subPositionIndex,
    bd: block.BlockData,
};

pub const meshData = struct {
    indices: []u32,
    positions: [][3]u4,
    normals: [][3]u2,
    block_data: []u32,
    full_offset: u32 = 0,
};

pub fn init(
    chunk_data: []const u32,
    pos: chunk.sub_chunk.subPosition,
    positions: [36][3]u4,
    indices: [36]u32,
    normals: [36][3]u2,
) chunkerSubChunker {
    var buffer: [chunk.sub_chunk.subChunkSize * @sizeOf(@Vector(4, f32))]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    var csc: chunkerSubChunker = .{
        .pos = pos,
        .positions = positions,
        .indices = indices,
        .normals = normals,
        .fba_buffer = buffer,
        .fba = fba,
        .allocator = fba.allocator(),
    };
    csc.run(chunk_data);
    return csc;
}

pub fn getMeshData(
    self: *chunkerSubChunker,
    indices_buf: *[chunk.sub_chunk.subChunkSize * 36]u32,
    positions_buf: *[chunk.sub_chunk.subChunkSize * 36][3]u4,
    normals_buf: *[chunk.sub_chunk.subChunkSize * 36][3]u2,
    block_data_buf: *[chunk.sub_chunk.subChunkSize * 36]u32,
    full_offset: u32,
) !meshData {
    var offset: u32 = 0;
    var i: usize = 0;
    while (i < self.num_meshes) : (i += 1) {
        const mesh = self.meshes[i];
        const sub_index_pos = mesh.sub_index_pos;
        var ii: usize = 0;
        while (ii < mesh.indices.len) : (ii += 1) {
            const index = mesh.indices[ii];
            indices_buf[ii + offset] = index + offset + full_offset;
            const mesh_pos: [3]u4 = mesh.positions[ii];
            positions_buf[ii + offset] = [3]u4{
                mesh_pos[0] + sub_index_pos[0],
                mesh_pos[1] + sub_index_pos[1],
                mesh_pos[2] + sub_index_pos[2],
            };
            normals_buf[ii + offset] = mesh.normals[ii];
            block_data_buf[ii + offset] = mesh.bd_id;
        }
        offset += @intCast(mesh.indices.len);
    }
    if (offset == 0) return ChunkerError.NoMeshData;
    return .{
        .indices = indices_buf[0..offset],
        .positions = positions_buf[0..offset],
        .normals = normals_buf[0..offset],
        .block_data = block_data_buf[0..offset],
        .full_offset = full_offset + offset,
    };
}

fn run(self: *chunkerSubChunker, chunk_data: []const u32) void {
    const pos_x: f32 = self.pos[0] * 16;
    const pos_y: f32 = self.pos[1] * 16;
    const pos_z: f32 = self.pos[2] * 16;

    var i: usize = 0;
    var x: usize = 0;
    while (x < chunk.sub_chunk.subChunkDim) : (x += 1) {
        const _x: f32 = @floatFromInt(x);
        var z: usize = 0;
        while (z < chunk.sub_chunk.subChunkDim) : (z += 1) {
            const _z: f32 = @floatFromInt(z);
            var y: usize = 0;
            while (y < chunk.sub_chunk.subChunkDim) : (y += 1) {
                const _y: f32 = @floatFromInt(y);
                const c_pos: @Vector(4, f32) = .{
                    _x + pos_x,
                    _y + pos_y,
                    _z + pos_z,
                    0,
                };
                const scd = chunk.sub_chunk.chunkPosToSubPositionData(c_pos);
                self.data[scd.sub_chunk_index] = .{
                    .scd = scd,
                    .bd_id = chunk_data[scd.chunk_index],
                    .bd = block.BlockData.fromId(chunk_data[scd.chunk_index]),
                };
                i += 1;
            }
        }
    }

    self.findQuads() catch @panic("nope");
    var it = self.mesh_map.iterator();
    while (it.next()) |e| {
        const sci = e.key_ptr.*;
        const scale = e.value_ptr.*;
        const vd = self.data[sci];
        self.meshes[self.num_meshes] = self.scaleMesh(vd, scale);
        self.num_meshes += 1;
    }

    i = 0;
    self.total_indices_count = 0;
    while (i < self.num_meshes) : (i += 1) {
        self.total_indices_count += self.meshes[i].indices.len;
    }
}

fn scaleMesh(self: *chunkerSubChunker, vd: subChunkVoxelData, scale: @Vector(4, u4)) shubChunkMesh {
    var sm: shubChunkMesh = .{
        .sub_index_pos = vd.scd.sub_index_pos,
        .bd_id = vd.bd.toId(),
    };
    @memcpy(sm.indices[0..], self.indices[0..]);
    @memcpy(sm.positions[0..], self.positions[0..]);
    @memcpy(sm.normals[0..], self.normals[0..]);
    var pi: usize = 0;
    while (pi < sm.positions.len) : (pi += 1) {
        if (sm.positions[pi][0] > 0) {
            sm.positions[pi][0] = scale[0];
        }
        if (sm.positions[pi][1] > 0) {
            sm.positions[pi][1] = scale[1];
        }
        if (sm.positions[pi][2] > 0) {
            sm.positions[pi][2] = scale[2];
        }
    }
    return sm;
}

fn updateMeshed(self: *chunkerSubChunker, i: usize) void {
    if (self.num_voxels_in_mesh < min_voxels_in_mesh) {
        self.to_be_meshed[self.num_voxels_in_mesh] = i;
        self.num_voxels_in_mesh += 1;
        return;
    }
    if (self.caching_meshed) {
        for (self.to_be_meshed) |ii| {
            self.meshed[ii] = true;
        }
        self.caching_meshed = false;
        self.to_be_meshed = [_]usize{0} ** min_voxels_in_mesh;
    }
    self.meshed[i] = true;
}

fn updateQuads(self: *chunkerSubChunker) void {
    self.mesh_map.put(self.allocator, self.current_voxel, self.current_scale) catch @panic("OOM");
    self.to_be_meshed = [_]usize{0} ** min_voxels_in_mesh;
    self.num_voxels_in_mesh = 0;
    self.initScale();
    self.caching_meshed = true;
}

fn initScale(self: *chunkerSubChunker) void {
    self.current_scale = .{ 0, 0, 0, 0 };
}

fn findQuads(self: *chunkerSubChunker) !void {
    var op: @Vector(4, u8) = .{ 0, 0, 0, 0 };
    var p = op;
    p[0] += 1;
    var i: usize = 0;
    var first_loop = true;
    outer: while (true) {
        var num_dims_travelled: u8 = 1;
        while (true) {
            if (first_loop) {
                // first loop, skip iterating
                first_loop = false;
                break;
            }
            i += 1;
            if (i >= chunk.sub_chunk.subChunkSize) {
                break :outer;
            }
            op = self.data[i].scd.sub_index_pos;
            p = op;
            if (p[1] >= chunk.sub_chunk.subChunkDim) @breakpoint();
            if (p[0] + 1 < chunk.sub_chunk.subChunkDim) {
                p[0] += 1;
                break;
            }
            if (p[2] + 1 < chunk.sub_chunk.subChunkDim) {
                num_dims_travelled = 2;
                p[2] += 1;
                break;
            }
            if (p[1] + 1 < chunk.sub_chunk.subChunkDim) {
                num_dims_travelled = 3;
                p[1] += 1;
                break;
            }
            continue;
        }
        const vd = self.data[i];
        if (vd.bd.block_id == 0) {
            continue :outer;
        }
        if (self.meshed[i]) {
            continue :outer;
        }
        self.current_voxel = i;
        var endX: u8 = op[0];
        var endZ: u8 = op[2];
        var numXAdded: u8 = 0;
        var numZAdded: u8 = 0;
        inner: while (true) {
            if (num_dims_travelled == 1) {
                const ii = chunk.sub_chunk.subChunkPosToSubPositionData(.{ @intCast(p[0]), @intCast(p[1]), @intCast(p[2]), 0 });
                if (vd.bd_id != self.data[ii].bd_id or self.meshed[ii]) {
                    num_dims_travelled += 1;
                    p[0] = op[0];
                    p[2] += 1;
                    p[1] = op[1]; // Happens when near chunk.sub_chunk.subChunkDims
                    continue :inner;
                }
                if (numXAdded == 0) {
                    numXAdded += 1;
                    self.updateMeshed(i);
                }
                self.updateMeshed(ii);
                endX = p[0];
                self.current_scale[0] = @intCast(endX - op[0]);
                p[0] += 1;
                if (p[0] >= chunk.sub_chunk.subChunkDim) {
                    num_dims_travelled += 1;
                    p[2] += 1;
                    p[0] = op[0];
                    continue :inner;
                }
                numXAdded += 1;
            } else if (num_dims_travelled == 2) {
                if (p[2] >= chunk.sub_chunk.subChunkDim) {
                    p[2] = op[2];
                    p[1] += 1;
                    if (p[1] >= chunk.sub_chunk.subChunkDim) {
                        break :inner;
                    }
                    num_dims_travelled += 1;
                    continue :inner;
                }
                const ii = chunk.sub_chunk.subChunkPosToSubPositionData(.{ @intCast(p[0]), @intCast(p[1]), @intCast(p[2]), 0 });
                // doing y here, only add if all x along the y are the same
                if (vd.bd_id != self.data[ii].bd_id or self.meshed[ii]) {
                    p[0] = op[0];
                    p[2] = op[2];
                    p[1] += 1;
                    if (p[1] >= chunk.sub_chunk.subChunkDim) {
                        break :inner;
                    }
                    num_dims_travelled += 1;
                    continue :inner;
                }
                if (numZAdded == 0) {
                    self.updateMeshed(i);
                }
                if (p[0] != endX) {
                    p[0] += 1;
                    continue :inner;
                }
                // need to add all x's along the y to meshed map
                const _beg = @as(usize, @intCast(op[0]));
                const _end = @as(usize, @intCast(endX)) + 1;
                for (_beg.._end) |xToAdd| {
                    const _xToAdd: u8 = @intCast(xToAdd);
                    const np: @Vector(4, u8) = .{ _xToAdd, p[1], p[2], 0 };
                    const iii = chunk.sub_chunk.subChunkPosToSubPositionData(.{ @intCast(np[0]), @intCast(np[1]), @intCast(np[2]), 0 });
                    if (self.data[iii].bd.block_id != 0) self.updateMeshed(iii);
                }
                numZAdded += 1;
                endZ = p[2];
                self.current_scale[2] = @intCast(endZ - op[2]);
                p[2] += 1;
                p[0] = op[0];
            } else {
                const ii = chunk.sub_chunk.subChunkPosToSubPositionData(.{ @intCast(p[0]), @intCast(p[1]), @intCast(p[2]), 0 });
                if (vd.bd_id != self.data[ii].bd_id) {
                    break :inner;
                }
                if (self.meshed[ii]) {
                    break :inner;
                }
                if (p[0] != endX) {
                    p[0] += 1;
                    continue :inner;
                }
                if (p[2] != endZ) {
                    p[2] += 1;
                    p[0] = op[0];
                    continue :inner;
                }
                // need to add all x's along the y to meshed map
                const _begX = @as(usize, @intCast(op[0]));
                const _endX = @as(usize, @intCast(endX)) + 1;
                for (_begX.._endX) |xToAdd| {
                    const _xToAdd: u8 = @intCast(xToAdd);
                    const _begZ = @as(usize, @intCast(op[2]));
                    const _endZ = @as(usize, @intCast(endZ)) + 1;
                    for (_begZ.._endZ) |zToAdd| {
                        const _zToAdd: u8 = @intCast(zToAdd);
                        const iii = chunk.sub_chunk.subChunkPosToSubPositionData(.{ @intCast(_xToAdd), @intCast(p[1]), @intCast(_zToAdd), 0 });
                        // a one off bug I think?
                        if (self.data[iii].bd.block_id != 0) self.updateMeshed(iii);
                    }
                }
                self.current_scale[1] = @intCast(p[1] - op[1]);
                p[1] += 1;
                p[0] = op[0];
                p[2] = op[2];
                if (p[1] >= chunk.sub_chunk.subChunkDim) {
                    break :inner;
                }
                continue :inner;
            }
        }
        self.updateQuads();
    }
    // check final voxel:
    i = chunk.sub_chunk.subChunkPosToSubPositionData(.{ 15, 15, 15, 0 });
    const vd = self.data[i];
    if (vd.bd.block_id == 0) {
        return;
    }
    if (self.meshed[i]) {
        return;
    }
    self.meshed[i] = true;
    self.mesh_map.put(self.allocator, i, .{ 0, 0, 0, 0 }) catch @panic("OOM");
}

pub const data_pkg = struct {
    positions: [3]u4,
    normals: [3]u2 = undefined,
};

pub fn dataToUint(d: data_pkg) u32 {
    var i: u32 = 0;
    const n1: u32 = @intCast(d.normals[0]);
    const n2: u32 = @intCast(d.normals[1]);
    const n3: u32 = @intCast(d.normals[2]);
    const x: u32 = @intCast(d.positions[0]);
    const y: u32 = @intCast(d.positions[1]);
    const z: u32 = @intCast(d.positions[2]);
    i |= (n1 << 16);
    i |= (n2 << 14);
    i |= (n3 << 12);
    i |= (x << 8);
    i |= (y << 4);
    i |= z;
    return i;
}

fn uintToData(i: u32) data_pkg {
    const n1: u32 = i >> 16 & 3;
    const n2: u32 = i >> 14 & 3;
    const n3: u32 = i >> 12 & 3;
    const x: u32 = (i >> 8) & 15;
    const y: u32 = (i >> 4) & 15;
    const z: u32 = i & 15;
    return .{
        .positions = .{ @intCast(x), @intCast(y), @intCast(z) },
        .normals = .{ @intCast(n1), @intCast(n2), @intCast(n3) },
    };
}

test dataToUint {
    const test_cases = [_]data_pkg{
        .{
            .positions = .{ 0, 0, 0 },
            .normals = .{ 0, 0, 0 },
        },
        .{
            .positions = .{ 1, 1, 1 },
            .normals = .{ 1, 1, 1 },
        },
        .{
            .positions = .{ 15, 15, 15 },
            .normals = .{ 2, 2, 2 },
        },
        .{
            .positions = .{ 1, 2, 3 },
            .normals = .{ 0, 1, 2 },
        },
        .{
            .positions = .{ 15, 14, 13 },
            .normals = .{ 2, 1, 0 },
        },
        .{
            .positions = .{ 15, 10, 5 },
            .normals = .{ 0, 0, 0 },
        },
    };
    for (test_cases, 0..) |tc, i| {
        errdefer std.debug.print("failed test with test case {any} at index {d}\n", .{ tc, i });
        const id = dataToUint(tc);
        const rs = uintToData(id);
        try std.testing.expectEqual(tc.positions, rs.positions);
        try std.testing.expectEqual(tc.normals, rs.normals);
    }
}

test run {
    const positions: [36][3]u4 = undefined;
    const indices: [36]u32 = undefined;
    const normals: [36][3]u2 = undefined;

    const chunk_data = std.testing.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
    defer std.testing.allocator.free(chunk_data);
    @memset(chunk_data, 0);
    var pos: @Vector(4, f32) = .{ 1, 2, 3, 0 };
    const scd = chunk.sub_chunk.chunkPosToSubPositionData(pos);
    var bd: block.BlockData = block.BlockData.fromId(chunk_data[scd.chunk_index]);
    bd.block_id = 3;
    chunk_data[scd.chunk_index] = bd.toId();
    const t1 = init(
        chunk_data,
        scd.sub_pos,
        positions,
        indices,
        normals,
    );
    try std.testing.expectEqual(chunk.sub_chunk.subChunkSize, t1.data.len);

    var tbd: block.BlockData = t1.data[scd.sub_chunk_index].bd;
    try std.testing.expectEqual(3, tbd.block_id);

    @memset(chunk_data, 0);
    pos = .{ 63, 63, 63, 0 };
    bd = block.BlockData.fromId(0);
    bd.block_id = 3;
    chunk_data[scd.chunk_index] = bd.toId();
    const t2 = init(
        chunk_data,
        scd.sub_pos,
        positions,
        indices,
        normals,
    );
    try std.testing.expectEqual(chunk.sub_chunk.subChunkSize, t2.data.len);
    tbd = t2.data[scd.sub_chunk_index].bd;
    try std.testing.expectEqual(3, tbd.block_id);
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
