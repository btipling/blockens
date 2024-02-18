const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");
const components = @import("../components/components.zig");
const helpers = @import("../helpers.zig");
const tags = @import("../tags.zig");

pub fn init() void {
    game.state.entities.screen = ecs.new_entity(game.state.world, "Screen");
    const gameData = ecs.new_entity(game.state.world, "ScreenGameData");
    const settingsData = ecs.new_entity(game.state.world, "ScreenSettingsData");
    const initialScreen = helpers.new_child(game.state.world, game.state.entities.screen);
    _ = ecs.add(game.state.world, initialScreen, components.screen.Game);
    _ = ecs.set(game.state.world, game.state.entities.screen, components.screen.Screen, .{
        .current = initialScreen,
        .gameDataEntity = gameData,
        .settingDataEntity = settingsData,
    });

    game.state.entities.clock = ecs.new_entity(game.state.world, "Clock");
    _ = ecs.set(game.state.world, game.state.entities.clock, components.Time, .{ .startTime = 0, .currentTime = 0 });

    game.state.entities.gfx = ecs.new_entity(game.state.world, "Gfx");
    _ = ecs.set(game.state.world, game.state.entities.gfx, components.gfx.BaseRenderer, .{
        .clear = gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT,
        .bgColor = math.vecs.Vflx4.initBytes(135, 206, 235, 255),
    });

    game.state.entities.sky = ecs.new_entity(game.state.world, "Sky");
    _ = ecs.set(game.state.world, game.state.entities.sky, components.Sky, .{
        .sun = .rising,
    });

    game.state.entities.crosshair = ecs.new_entity(game.state.world, "Crosshair");
    const c_hrz = helpers.new_child(game.state.world, game.state.entities.crosshair);
    _ = ecs.set(game.state.world, c_hrz, components.shape.Plane, .{
        .color = math.vecs.Vflx4.initBytes(33, 33, 33, 255),
        .scale = math.vecs.Vflx4.initFloats(0.025, 0.004, 1, 0),
        .rotation = null,
        .translation = math.vecs.Vflx4.initFloats(-0.5, -0.5, 0, 0),
    });
    _ = ecs.add(game.state.world, c_hrz, tags.Hud);
    _ = ecs.add(game.state.world, c_hrz, components.shape.NeedsSetup);
    ecs.add_pair(game.state.world, c_hrz, ecs.ChildOf, gameData);
    const c_vrt = helpers.new_child(game.state.world, game.state.entities.crosshair);
    _ = ecs.set(game.state.world, c_vrt, components.shape.Plane, .{
        .color = math.vecs.Vflx4.initBytes(33, 33, 33, 255),
        .scale = math.vecs.Vflx4.initFloats(0.0025, 0.04, 1, 0),
        .rotation = null,
        .translation = math.vecs.Vflx4.initFloats(-0.5, -0.5, 0, 0),
    });
    _ = ecs.add(game.state.world, c_vrt, tags.Hud);
    _ = ecs.add(game.state.world, c_vrt, components.shape.NeedsSetup);
    ecs.add_pair(game.state.world, c_vrt, ecs.ChildOf, gameData);

    game.state.entities.menu = ecs.new_entity(game.state.world, "Menu");
    _ = ecs.set(game.state.world, game.state.entities.menu, components.ui.Menu, .{
        .visible = false,
    });
}