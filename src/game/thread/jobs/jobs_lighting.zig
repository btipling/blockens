const std = @import("std");
const game = @import("../../game.zig");
const chunk = @import("../../chunk.zig");
const blecs = @import("../../blecs/blecs.zig");
const data = @import("../../data/data.zig");
const config = @import("config");

pub const LightingJob = struct {
    wp: chunk.worldPosition,
    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("LightingJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "LightingJob", 0x00_C0_82_f0);
            defer tracy_zone.End();
            self.lightingJob();
        } else {
            self.lightingJob();
        }
    }

    pub fn lightingJob(self: *@This()) void {
        std.debug.print("doing a lighting {}\n", .{
            self.wp,
        });
        const c: *chunk.Chunk = game.state.blocks.game_chunks.get(self.wp) orelse return;
        std.debug.print("got a chunk bro {}\n", .{c.entity});
    }
};
