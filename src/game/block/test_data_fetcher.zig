const data_fetcher = @This();

pub fn fetch(_: data_fetcher, wp: chunk.worldPosition) ?lighting.datas {
    const data: [chunk.chunkSize]u32 = std.mem.zeroes([chunk.chunkSize]u32);
    const c_data = std.testing.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
    {
        @memcpy(c_data, data[0..]);
    }
    return .{
        .wp = wp,
        .data = c_data,
    };
}

const std = @import("std");
const block = @import("block.zig");
const lighting = @import("lighting.zig");
const chunk = block.chunk;
