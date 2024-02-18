const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");
const components = @import("../components/components.zig");
const helpers = @import("../helpers.zig");

pub fn init() void {
    initBaseRenderer();
    initClock();
    initSky();
}

fn initBaseRenderer() void {
    game.state.entities.gfx = ecs.new_entity(game.state.world, "Gfx");
    _ = ecs.set(game.state.world, game.state.entities.gfx, components.gfx.BaseRenderer, .{
        .clear = gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT,
        .bgColor = math.vecs.Vflx4.initBytes(135, 206, 235, 255),
    });
}

fn initClock() void {
    game.state.entities.clock = ecs.new_entity(game.state.world, "Clock");
    _ = ecs.set(game.state.world, game.state.entities.clock, components.Time, .{ .startTime = 0, .currentTime = 0 });
}

fn initSky() void {
    game.state.entities.sky = ecs.new_entity(game.state.world, "Sky");
    _ = ecs.set(game.state.world, game.state.entities.sky, components.Sky, .{
        .sun = .rising,
    });
}
