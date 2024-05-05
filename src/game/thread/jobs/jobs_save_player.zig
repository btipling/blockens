const default_pos: @Vector(4, f32) = .{ 0, 0, 0, 0 };

pub const PlayerPosition = struct {
    loc: @Vector(4, f32) = default_pos,
    rotation: @Vector(4, f32) = .{ 0, 0, 0, 0 },
    angle: f32 = 0,
};

pub const SavePlayerJob = struct {
    player_position: PlayerPosition,
    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("SavePlayerJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "SavePlayerJob", 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.savePlayerJob();
        } else {
            self.savePlayerJob();
        }
    }

    pub fn savePlayerJob(self: *@This()) void {
        const loaded_world = game.state.ui.world_loaded_id;
        const pp = self.player_position;
        const pl: [4]f32 = pp.loc;
        const dp: [4]f32 = default_pos;
        if (std.mem.eql(f32, pl[0..], dp[0..])) return; // don't save unset player position
        game.state.db.updatePlayerPosition(
            loaded_world,
            pp.loc,
            pp.rotation,
            pp.angle,
        ) catch @panic("DB error");
    }
};

const std = @import("std");
const game = @import("../../game.zig");
const blecs = @import("../../blecs/blecs.zig");
const data = @import("../../data/data.zig");
const config = @import("config");
