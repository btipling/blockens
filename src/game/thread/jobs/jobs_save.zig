const std = @import("std");
const game = @import("../../game.zig");
const chunk = @import("../../chunk.zig");
const blecs = @import("../../blecs/blecs.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");

pub const SaveJob = struct {
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
        self.savePlayerPosition() catch std.debug.print("unable o save player position\n", .{});
    }

    pub fn savePlayerPosition(_: *@This()) !void {
        const world = game.state.world;
        const player = game.state.entities.player;
        const loaded_world = game.state.ui.data.world_loaded_id;
        var loc: @Vector(4, f32) = .{ 1, 1, 1, 1 };
        var rotation: @Vector(4, f32) = .{ 0, 0, 0, 1 };
        var angle: f32 = 0;
        if (blecs.ecs.get(world, player, blecs.components.mob.Position)) |p| {
            loc = p.position;
        }
        if (blecs.ecs.get(world, player, blecs.components.mob.Rotation)) |r| {
            rotation = r.rotation;
            angle = r.angle;
        }
        try game.state.db.updatePlayerPosition(loaded_world, loc, rotation, angle);
    }
};
