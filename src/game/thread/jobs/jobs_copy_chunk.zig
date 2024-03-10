const std = @import("std");
const game = @import("../../game.zig");
const chunk = @import("../../chunk.zig");
const state = @import("../../state/state.zig");
const blecs = @import("../../blecs/blecs.zig");
const buffer = @import("../buffer.zig");

pub const CopyChunkJob = struct {
    wp: state.position.worldPosition,

    pub fn exec(self: *@This()) void {
        const ch_cfg = game.state.ui.data.world_chunk_table_data.get(self.wp) orelse return;

        var c: *chunk.Chunk = chunk.Chunk.init(game.state.allocator) catch unreachable;

        c.data = game.state.allocator.alloc(i32, ch_cfg.chunkData.len) catch unreachable;
        @memcpy(c.data, ch_cfg.chunkData);

        var msg: buffer.buffer_message = buffer.new_message(.chunk_copy);
        buffer.set_progress(&msg, true, 1);
        buffer.put_chunk_copy_data(msg, .{
            .wp = self.wp,
            .chunk = c,
        }) catch unreachable;
        buffer.write_message(msg) catch unreachable;
    }
};
