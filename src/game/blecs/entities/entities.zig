const ecs = @import("zflecs");
const gl = @import("zopengl");
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");
const components = @import("../components/components.zig");
const tags = @import("../tags.zig");

pub fn init() void {
    game.state.entities.screen = ecs.new_entity(game.state.world, "Screen");
    _ = ecs.add(game.state.world, game.state.entities.screen, components.screen.Game);

    game.state.entities.clock = ecs.new_entity(game.state.world, "Clock");
    _ = ecs.set(game.state.world, game.state.entities.clock, components.Time, .{ .startTime = 0, .currentTime = 0 });

    game.state.entities.gfx = ecs.new_entity(game.state.world, "Gfx");
    _ = ecs.set(game.state.world, game.state.entities.gfx, components.gfx.BaseRenderer, .{
        .clear = gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT,
        .bgColor = math.vecs.Vflx4.initBytes(135, 206, 235, 1.0),
    });

    game.state.entities.sky = ecs.new_entity(game.state.world, "Sky");
    _ = ecs.set(game.state.world, game.state.entities.sky, components.Sky, .{
        .sun = .rising,
    });

    game.state.entities.crosshair = ecs.new_entity(game.state.world, "Crosshair");
    _ = ecs.set(game.state.world, game.state.entities.crosshair, components.shape.Plane, .{
        .color = math.vecs.Vflx4.initBytes(135, 206, 235, 1.0),
        .translate = null,
        .scale = null,
        .rotation = null,
    });
    _ = ecs.add(game.state.world, game.state.entities.crosshair, tags.Hud);
    _ = ecs.add(game.state.world, game.state.entities.crosshair, components.shape.NeedsSetup);
}
