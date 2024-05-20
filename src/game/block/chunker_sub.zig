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
                const ci = chunk.getIndexFromPositionV(.{
                    _x + pos_x,
                    _y + pos_y,
                    _z + pos_z,
                    0,
                });
                sub_chunk_data[i] = chunk_data[ci];
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
    const actual = chunkToSubChunk(std.testing.allocator, chunk_data, .{ 0, 0, 0, 0 });
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqual(chunk.subchunk.subChunkSize, actual.len);
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
