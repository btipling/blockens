pos: chunk.sub_chunk.subPosition,
data: [chunk.sub_chunk.subChunkSize]subChunkVoxelData = undefined,
total_indices_count: usize = 0,
// these are used to generate vertices for each surface
positions: [36][3]f32,
indices: [36]u32,
normals: [36][3]f32,

const chunkerSubChunker = @This();

pub const ChunkerError = error{
    NoMeshData,
};

pub fn init(
    chunk_data: []const u32,
    pos: chunk.sub_chunk.subPosition,
    positions: [36][3]f32,
    indices: [36]u32,
    normals: [36][3]f32,
) chunkerSubChunker {
    var csc: chunkerSubChunker = .{
        .pos = pos,
        .positions = positions,
        .indices = indices,
        .normals = normals,
    };
    csc.run(chunk_data);
    return csc;
}

pub const subChunkVoxelData = struct {
    scd: chunk.sub_chunk.subPositionIndex,
    bd: block.BlockData,
    positions: [36][3]f32 = undefined,
    indices: [36]u32 = undefined,
    normals: [36][3]f32 = undefined,
    num_indices: usize = 0,
};

pub const meshData = struct {
    indices: []u32,
    positions: [][3]f32,
    normals: [][3]f32,
    block_data: []u32,
    full_offset: u32 = 0,
};

pub fn getMeshData(
    self: *chunkerSubChunker,
    indices_buf: *[chunk.sub_chunk.subChunkSize * 36]u32,
    vertices_buf: *[chunk.sub_chunk.subChunkSize * 36][3]f32,
    normals_buf: *[chunk.sub_chunk.subChunkSize * 36][3]f32,
    block_data_buf: *[chunk.sub_chunk.subChunkSize * 36]u32,
    full_offset: u32,
) !meshData {
    var offset: u32 = 0;
    var i: usize = 0;
    while (i < chunk.sub_chunk.subChunkSize) : (i += 1) {
        const vd = self.data[i];
        const sub_index_pos = vd.scd.sub_index_pos;
        var ii: usize = 0;
        while (ii < vd.num_indices) : (ii += 1) {
            const index = vd.indices[ii];
            indices_buf[ii + offset] = index + offset + full_offset;
            const vd_pos: [3]f32 = vd.positions[ii];
            vertices_buf[ii + offset] = [3]f32{
                vd_pos[0] + sub_index_pos[0],
                vd_pos[1] + sub_index_pos[1],
                vd_pos[2] + sub_index_pos[2],
            };
            normals_buf[ii + offset] = vd.normals[ii];
            block_data_buf[ii + offset] = vd.bd.toId();
        }
        offset += @intCast(vd.num_indices);
    }
    if (offset == 0) return ChunkerError.NoMeshData;
    return .{
        .indices = indices_buf[0..offset],
        .positions = vertices_buf[0..offset],
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
                    .bd = block.BlockData.fromId(chunk_data[scd.chunk_index]),
                };
                i += 1;
            }
        }
    }
    i = 0;

    var surfaces: [6]?block.BlockData = undefined;
    const xp: usize = 0;
    const xn: usize = 1;
    const yp: usize = 2;
    const yn: usize = 3;
    const zp: usize = 4;
    const zn: usize = 5;

    while (i < chunk.sub_chunk.subChunkSize) : (i += 1) {
        var vd = self.data[i];
        if (vd.bd.block_id == 0) continue;

        // get blocks facing each surface:
        // x_pos
        if (vd.scd.sub_index_pos[0] + 1 >= chunk.sub_chunk.subChunkDim) surfaces[xp] = null else {
            var p = vd.scd.sub_index_pos;
            p[0] += 1;
            const sci = chunk.sub_chunk.subChunkPosToSubPositionData(p);
            surfaces[xp] = self.data[sci].bd;
        }
        // x_neg
        if (vd.scd.sub_index_pos[0] == 0) surfaces[xn] = null else {
            var p = vd.scd.sub_index_pos;
            p[0] -= 1;
            const sci = chunk.sub_chunk.subChunkPosToSubPositionData(p);
            surfaces[xn] = self.data[sci].bd;
        }
        // y_pos
        if (vd.scd.sub_index_pos[1] + 1 >= chunk.sub_chunk.subChunkDim) surfaces[yp] = null else {
            var p = vd.scd.sub_index_pos;
            p[1] += 1;
            const sci = chunk.sub_chunk.subChunkPosToSubPositionData(p);
            surfaces[yp] = self.data[sci].bd;
        }
        // y_neg
        if (vd.scd.sub_index_pos[1] == 0) surfaces[yn] = null else {
            var p = vd.scd.sub_index_pos;
            p[1] -= 1;
            const sci = chunk.sub_chunk.subChunkPosToSubPositionData(p);
            surfaces[yn] = self.data[sci].bd;
        }
        // z_pos
        if (vd.scd.sub_index_pos[2] + 1 >= chunk.sub_chunk.subChunkDim) surfaces[zp] = null else {
            var p = vd.scd.sub_index_pos;
            p[2] += 1;
            const sci = chunk.sub_chunk.subChunkPosToSubPositionData(p);
            surfaces[zp] = self.data[sci].bd;
        }
        // z_neg
        if (vd.scd.sub_index_pos[2] == 0) surfaces[zn] = null else {
            var p = vd.scd.sub_index_pos;
            p[2] -= 1;
            const sci = chunk.sub_chunk.subChunkPosToSubPositionData(p);
            surfaces[zn] = self.data[sci].bd;
        }

        x_pos: {
            if (surfaces[xp]) |bd| if (bd.block_id != 0) break :x_pos;

            const vx_i: usize = 6; // x_pos goes 6 - 12 in cube mesh
            const end = vx_i + 6;
            const n = vd.num_indices;
            const e = vd.num_indices + 6;
            @memcpy(vd.indices[n..e], self.indices[n..e]);
            @memcpy(vd.positions[n..e], self.positions[vx_i..end]);
            @memcpy(vd.normals[n..e], self.normals[vx_i..end]);
            vd.num_indices += 6;
        }
        x_neg: {
            if (surfaces[xn]) |bd| if (bd.block_id != 0) break :x_neg;

            const vx_i: usize = 18; // x_neg goes 18 - 24 in cube mesh
            const end = vx_i + 6;
            const n = vd.num_indices;
            const e = vd.num_indices + 6;
            @memcpy(vd.indices[n..e], self.indices[n..e]);
            @memcpy(vd.positions[n..e], self.positions[vx_i..end]);
            @memcpy(vd.normals[n..e], self.normals[vx_i..end]);
            vd.num_indices += 6;
        }
        y_pos: {
            if (surfaces[yp]) |bd| if (bd.block_id != 0) break :y_pos;

            const vx_i: usize = 30; // y_pos goes 30 - 36 in cube mesh
            const end = vx_i + 6;
            const n = vd.num_indices;
            const e = vd.num_indices + 6;
            @memcpy(vd.indices[n..e], self.indices[n..e]);
            @memcpy(vd.positions[n..e], self.positions[vx_i..end]);
            @memcpy(vd.normals[n..e], self.normals[vx_i..end]);
            vd.num_indices += 6;
        }
        y_neg: {
            if (surfaces[yn]) |bd| if (bd.block_id != 0) break :y_neg;

            const vx_i: usize = 24; // y_neg goes 24 - 30 in cube mesh
            const end = vx_i + 6;
            const n = vd.num_indices;
            const e = vd.num_indices + 6;
            @memcpy(vd.indices[n..e], self.indices[n..e]);
            @memcpy(vd.positions[n..e], self.positions[vx_i..end]);
            @memcpy(vd.normals[n..e], self.normals[vx_i..end]);
            vd.num_indices += 6;
        }
        z_pos: {
            if (surfaces[zp]) |bd| if (bd.block_id != 0) break :z_pos;

            const vx_i: usize = 0; // z_pos goes 0 - 6 in cube mesh
            const end = vx_i + 6;
            const n = vd.num_indices;
            const e = vd.num_indices + 6;
            @memcpy(vd.indices[n..e], self.indices[n..e]);
            @memcpy(vd.positions[n..e], self.positions[vx_i..end]);
            @memcpy(vd.normals[n..e], self.normals[vx_i..end]);
            vd.num_indices += 6;
        }
        z_neg: {
            if (surfaces[zn]) |bd| if (bd.block_id != 0) break :z_neg;

            const vx_i: usize = 12; // z_neg goes 12 - 18 in cube mesh
            const end = vx_i + 6;
            const n = vd.num_indices;
            const e = vd.num_indices + 6;
            @memcpy(vd.indices[n..e], self.indices[n..e]);
            @memcpy(vd.positions[n..e], self.positions[vx_i..end]);
            @memcpy(vd.normals[n..e], self.normals[vx_i..end]);
            vd.num_indices += 6;
        }
        self.total_indices_count += vd.num_indices;
        self.data[i] = vd;
    }
}

test run {
    const positions: [36][3]f32 = undefined;
    const indices: [36]u32 = undefined;
    const normals: [36][3]f32 = undefined;

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
