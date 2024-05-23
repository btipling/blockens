pos: chunk.subchunk.subPosition,
data: [chunk.subchunk.subChunkSize]subChunkVoxelData = undefined,
positions: [36][3]f32,
indices: [36]u32,
normals: [36][3]f32,

const chunkerSubChunker = @This();

pub const ChunkerError = error{
    NoMeshData,
};

pub fn init(
    chunk_data: []const u32,
    pos: chunk.subchunk.subPosition,
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
    scd: chunk.subchunk.subPositionIndex,
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
    indices_buf: *[chunk.subchunk.subChunkSize * 36]u32,
    vertices_buf: *[chunk.subchunk.subChunkSize * 36][3]f32,
    normals_buf: *[chunk.subchunk.subChunkSize * 36][3]f32,
    block_data_buf: *[chunk.subchunk.subChunkSize * 36]u32,
    full_offset: u32,
) !meshData {
    var offset: u32 = 0;
    var i: usize = 0;
    while (i < chunk.subchunk.subChunkSize) : (i += 1) {
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
    while (x < chunk.subchunk.subChunkDim) : (x += 1) {
        const _x: f32 = @floatFromInt(x);
        var z: usize = 0;
        while (z < chunk.subchunk.subChunkDim) : (z += 1) {
            const _z: f32 = @floatFromInt(z);
            var y: usize = 0;
            while (y < chunk.subchunk.subChunkDim) : (y += 1) {
                const _y: f32 = @floatFromInt(y);
                const c_pos: @Vector(4, f32) = .{
                    _x + pos_x,
                    _y + pos_y,
                    _z + pos_z,
                    0,
                };
                const scd = chunk.subchunk.chunkPosToSubPositionData(c_pos);
                self.data[scd.sub_chunk_index] = .{
                    .scd = scd,
                    .bd = block.BlockData.fromId(chunk_data[scd.chunk_index]),
                };
                i += 1;
            }
        }
    }
    i = 0;
    while (i < chunk.subchunk.subChunkSize) : (i += 1) {
        var vd = self.data[i];
        if (vd.bd.block_id == 0) continue;
        x_pos: {
            if (vd.scd.sub_index_pos[0] + 1 >= chunk.subchunk.subChunkDim) {
                const n = vd.num_indices;
                const e = vd.num_indices + 6;
                const ob: usize = 6;
                const oe: usize = 12;
                @memcpy(vd.indices[n..e], self.indices[n..e]);
                @memcpy(vd.positions[n..e], self.positions[ob..oe]);
                @memcpy(vd.normals[n..e], self.normals[ob..oe]);
                vd.num_indices += 6;
                break :x_pos;
            }
        }
        x_neg: {
            if (vd.scd.sub_index_pos[0] == 0) {
                const n = vd.num_indices;
                const e = vd.num_indices + 6;
                const ob: usize = 18;
                const oe: usize = 24;
                @memcpy(vd.indices[n..e], self.indices[n..e]);
                @memcpy(vd.positions[n..e], self.positions[ob..oe]);
                @memcpy(vd.normals[n..e], self.normals[ob..oe]);
                vd.num_indices += 6;
                break :x_neg;
            }
        }
        y_pos: {
            if (vd.scd.sub_index_pos[1] == chunk.subchunk.subChunkDim - 1) {
                const n = vd.num_indices;
                const e = vd.num_indices + 6;
                const ob: usize = 30;
                const oe: usize = 36;
                @memcpy(vd.indices[n..e], self.indices[n..e]);
                @memcpy(vd.positions[n..e], self.positions[ob..oe]);
                @memcpy(vd.normals[n..e], self.normals[ob..oe]);
                vd.num_indices += 6;
                break :y_pos;
            }
        }
        y_neg: {
            if (vd.scd.sub_index_pos[1] == 0) {
                const n = vd.num_indices;
                const e = vd.num_indices + 6;
                const ob: usize = 24;
                const oe: usize = 30;
                @memcpy(vd.indices[n..e], self.indices[n..e]);
                @memcpy(vd.positions[n..e], self.positions[ob..oe]);
                @memcpy(vd.normals[n..e], self.normals[ob..oe]);
                vd.num_indices += 6;
                break :y_neg;
            }
        }
        z_pos: {
            if (vd.scd.sub_index_pos[2] == chunk.subchunk.subChunkDim - 1) {
                const n = vd.num_indices;
                const e = vd.num_indices + 6;
                const ob: usize = 0;
                const oe: usize = 6;
                @memcpy(vd.indices[n..e], self.indices[n..e]);
                @memcpy(vd.positions[n..e], self.positions[ob..oe]);
                @memcpy(vd.normals[n..e], self.normals[ob..oe]);
                vd.num_indices += 6;
                break :z_pos;
            }
        }
        z_neg: {
            if (vd.scd.sub_index_pos[2] == 0) {
                const n = vd.num_indices;
                const e = vd.num_indices + 6;
                const ob: usize = 12;
                const oe: usize = 18;
                @memcpy(vd.indices[n..e], self.indices[n..e]);
                @memcpy(vd.positions[n..e], self.positions[ob..oe]);
                @memcpy(vd.normals[n..e], self.normals[ob..oe]);
                vd.num_indices += 6;
                break :z_neg;
            }
        }
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
    const scd = chunk.subchunk.chunkPosToSubPositionData(pos);
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
    try std.testing.expectEqual(chunk.subchunk.subChunkSize, t1.data.len);

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
    try std.testing.expectEqual(chunk.subchunk.subChunkSize, t2.data.len);
    tbd = t2.data[scd.sub_chunk_index].bd;
    try std.testing.expectEqual(3, tbd.block_id);
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
