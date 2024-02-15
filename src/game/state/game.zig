const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");

pub const Entities = struct {
    clock: usize = 0,
    gfx: usize = 0,
    sky: usize = 0,
    floor: usize = 0,
};

pub const Game = struct {
    world: *ecs.world_t = undefined,
    entities: Entities = .{},
};
