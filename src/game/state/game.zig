const std = @import("std");
const glfw = @import("zglfw");
const ecs = @import("zflecs");
const gl = @import("zopengl");

pub const Entities = struct {
    clock: usize = 0,
    gfx: usize = 0,
    sky: usize = 0,
    floor: usize = 0,
    crosshair: usize = 0,
};

pub const Game = struct {
    allocator: std.mem.Allocator = undefined,
    window: *glfw.Window = undefined,
    world: *ecs.world_t = undefined,
    entities: Entities = .{},
};
