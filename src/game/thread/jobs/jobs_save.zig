const std = @import("std");
const game = @import("../../game.zig");
const chunk = @import("../../chunk.zig");
const blecs = @import("../../blecs/blecs.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");

pub const PlayerPosition = struct {
    loc: @Vector(4, f32),
    rotation: @Vector(4, f32) = .{ 0, 0, 0, 1 },
    angle: f32,
};
pub const SaveData = struct {
    player_position: PlayerPosition,
};

pub const SaveJob = struct {
    data: SaveData,
    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("SaveJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "SaveJob", 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.saveJob();
        } else {
            self.saveJob();
        }
    }

    pub fn saveJob(self: *@This()) void {
        self.savePlayerPosition() catch std.debug.print("unable to save player position\n", .{});
    }

    pub fn savePlayerPosition(self: *@This()) !void {
        const loaded_world = game.state.ui.data.world_loaded_id;
        const pp = self.data.player_position;
        try game.state.db.updatePlayerPosition(loaded_world, pp.loc, pp.rotation, pp.angle);
    }
};
