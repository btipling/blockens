const std = @import("std");
const ecs = @import("zflecs");

pub const Game = struct {
    world: *ecs.world_t = undefined,
};
