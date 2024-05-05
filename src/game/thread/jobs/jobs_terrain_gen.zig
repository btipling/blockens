pub const TerrainGenJob = struct {
    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("TerrainGen");
            const tracy_zone = ztracy.ZoneNC(@src(), "TerrainGen", 0xF0_00_ff_f0);
            defer tracy_zone.End();
            self.terrainGenJob();
        } else {
            self.terrainGenJob();
        }
    }

    pub fn terrainGenJob(self: *@This()) void {
        _ = self; // autofix
        var msg: buffer.buffer_message = buffer.new_message(.terrain_gen);
        buffer.set_progress(&msg, true, 1);
        const bd: buffer.buffer_data = .{
            .terrain_gen = .{
                .position = .{ 0, 0, 0, 0 },
            },
        };
        buffer.put_data(msg, bd) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("unable to write message");
    }
};

const std = @import("std");
const game = @import("../../game.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
const state = @import("../../state.zig");
const blecs = @import("../../blecs/blecs.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");
