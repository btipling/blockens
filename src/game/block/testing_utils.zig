pub fn utest_add_floor_at_y(data: []u32, y: f32, top_ambiance: block.BlockLighingLevel) void {
    {
        // set a lit ground floor across y = 63 on bottom chunk
        var ground_bd: block.BlockData = block.BlockData.fromId(1);
        ground_bd.setFullAmbiance(.none);
        ground_bd.setAmbient(.top, top_ambiance);
        const gd: u32 = ground_bd.toId();
        var x: f32 = 0;
        while (x < chunk.chunkDim) : (x += 1) {
            var z: f32 = 0;
            while (z < chunk.chunkDim) : (z += 1) {
                const ci = chunk.getIndexFromPositionV(.{ x, y, z, 0 });
                data[ci] = gd;
            }
        }
    }
}

pub fn utest_allocate_test_chunk(id: u32, ambiance: block.BlockLighingLevel) []u32 {
    const data = std.testing.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
    {
        var init_bd: block.BlockData = block.BlockData.fromId(id);
        init_bd.setFullAmbiance(ambiance);
        const init_data: u32 = init_bd.toId();
        var d: [chunk.chunkSize]u32 = undefined;
        @memset(&d, init_data);
        @memcpy(data, d[0..]);
    }
    return data;
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
