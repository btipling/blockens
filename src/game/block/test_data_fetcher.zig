const data_fetcher = @This();

test_chunk_data: std.AutoHashMap(chunk.worldPosition, []u32) = undefined,

pub fn fetch(self: *data_fetcher, wp: chunk.worldPosition) ?lighting.datas {
    const d: []u32 = self.test_chunk_data.get(wp) orelse return null;
    const c_data = std.testing.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
    @memcpy(c_data, d);
    return .{
        .wp = wp,
        .data = c_data,
    };
}

pub fn init(self: *data_fetcher) void {
    self.test_chunk_data = std.AutoHashMap(chunk.worldPosition, []u32).init(std.testing.allocator);
}

pub fn deinit(self: *data_fetcher) void {
    var iter = self.test_chunk_data.iterator();
    while (iter.next()) |e| {
        const d: []u32 = e.value_ptr.*;
        std.testing.allocator.free(d);
    }
    self.test_chunk_data.deinit();
}

const std = @import("std");
const block = @import("block.zig");
const lighting = @import("lighting_ambient_edit.zig");
const chunk = block.chunk;
