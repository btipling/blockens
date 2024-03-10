const std = @import("std");
const ecs = @import("zflecs");
const game = @import("../../game.zig");
pub var HasMesh: ecs.entity_t = 0;

pub fn init() void {
    HasMesh = ecs.new_id(game.state.world);
    std.debug.print("hasmesh: {d}\n", .{HasMesh});
}
