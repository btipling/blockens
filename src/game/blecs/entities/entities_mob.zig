pub var HasMesh: ecs.entity_t = 0;
pub var HasBoundingBox: ecs.entity_t = 0;

pub fn init() void {
    const world = game.state.world;
    HasMesh = ecs.new_id(world);
    HasBoundingBox = ecs.new_id(world);
}

const std = @import("std");
const ecs = @import("zflecs");
const game = @import("../../game.zig");
