pub fn chunkToSubChunk(allocator: std.mem.Allocator, chunk_data: []u32, pos: chunk.subchunk.subPosition) []u32 {
    const sub_chunk_data: []u32 = allocator.alloc(u32, chunk.subchunk.subChunkSize) catch @panic("OOM");
    errdefer allocator.free(sub_chunk_data);

    const pos_x: f32 = pos[0] * 16;
    const pos_y: f32 = pos[1] * 16;
    const pos_z: f32 = pos[2] * 16;

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
                sub_chunk_data[scd.sub_chunk_index] = chunk_data[scd.chunk_index];
                i += 1;
            }
        }
    }
    return sub_chunk_data;
}

test chunkToSubChunk {
    const chunk_data = std.testing.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
    defer std.testing.allocator.free(chunk_data);
    @memset(chunk_data, 0);
    var pos: @Vector(4, f32) = .{ 1, 2, 3, 0 };
    const scd = chunk.subchunk.chunkPosToSubPositionData(pos);
    var bd: block.BlockData = block.BlockData.fromId(chunk_data[scd.chunk_index]);
    bd.block_id = 3;
    chunk_data[scd.chunk_index] = bd.toId();
    const t1 = chunkToSubChunk(std.testing.allocator, chunk_data, scd.sub_pos);
    defer std.testing.allocator.free(t1);
    try std.testing.expectEqual(chunk.subchunk.subChunkSize, t1.len);

    var tbd: block.BlockData = block.BlockData.fromId(t1[scd.sub_chunk_index]);
    try std.testing.expectEqual(3, tbd.block_id);

    @memset(chunk_data, 0);
    pos = .{ 63, 63, 63, 0 };
    bd = block.BlockData.fromId(0);
    bd.block_id = 3;
    chunk_data[scd.chunk_index] = bd.toId();
    const t2 = chunkToSubChunk(std.testing.allocator, chunk_data, scd.sub_pos);
    defer std.testing.allocator.free(t2);
    try std.testing.expectEqual(chunk.subchunk.subChunkSize, t2.len);
    tbd = block.BlockData.fromId(t2[scd.sub_chunk_index]);
    try std.testing.expectEqual(3, tbd.block_id);
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
