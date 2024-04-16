const data_fetcher = @This();

pub fn fetch(_: data_fetcher, wp: chunk.worldPosition) ?lighting.datas {
    const c: *chunk.Chunk = game.state.blocks.game_chunks.get(wp) orelse return null;

    const c_data = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
    {
        c.mutex.lock();
        defer c.mutex.unlock();
        @memcpy(c_data, c.data);
    }
    return .{
        .wp = wp,
        .data = c_data,
    };
}

const game = @import("../../game.zig");
const block = @import("../block.zig");
const lighting = @import("ambient_edit.zig");
const chunk = block.chunk;
