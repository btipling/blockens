const std = @import("std");
const game = @import("../../game.zig");
const chunk = @import("../../chunk.zig");
const state = @import("../../state.zig");
const blecs = @import("../../blecs/blecs.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");

pub const CopyChunkJob = struct {
    wp: chunk.worldPosition,
    entity: blecs.ecs.entity_t,
    is_settings: bool,
    schedule_save: bool,

    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("CopyChunkJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "CopyChunkJob", 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.copyChunkJob();
        } else {
            self.copyChunkJob();
        }
    }

    pub fn copyChunkJob(self: *@This()) void {
        var c: *chunk.Chunk = chunk.Chunk.init(
            game.state.allocator,
            self.wp,
            self.entity,
            self.is_settings,
        ) catch unreachable;
        c.updated = self.schedule_save;
        if (self.is_settings) {
            c.data = game.state.allocator.alloc(u32, game.state.ui.data.chunk_demo_data.?.len) catch unreachable;
            @memcpy(c.data, game.state.ui.data.chunk_demo_data.?);
        } else {
            const ch_cfg = game.state.ui.data.world_chunk_table_data.get(self.wp) orelse return;
            c.data = game.state.allocator.alloc(u32, ch_cfg.chunkData.len) catch unreachable;
            @memcpy(c.data, ch_cfg.chunkData);
        }

        var msg: buffer.buffer_message = buffer.new_message(.chunk_copy);
        buffer.set_progress(&msg, true, 1);
        buffer.put_chunk_copy_data(msg, .{
            .chunk = c,
        }) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("unable to write message");
    }
};
