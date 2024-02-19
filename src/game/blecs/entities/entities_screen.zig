const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");
const config = @import("../../config.zig");
const components = @import("../components/components.zig");
const helpers = @import("../helpers.zig");

pub const GameUBOBindingPoint: gl.Uint = 0;

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

    initCrossHairs(gameData);
    initFloor(gameData);
    initMenu();
    initCamera(gameData);
}

fn initMenu() void {
    game.state.entities.menu = ecs.new_entity(game.state.world, "Menu");
    _ = ecs.set(game.state.world, game.state.entities.menu, components.ui.Menu, .{
        .visible = false,
    });
}

fn initCrossHairs(gameData: ecs.entity_t) void {
    game.state.entities.crosshair = ecs.new_entity(game.state.world, "Crosshair");
    const c_hrz = helpers.new_child(game.state.world, game.state.entities.crosshair);
    _ = ecs.add(game.state.world, c_hrz, components.shape.Shape);
    const cr_c = math.vecs.Vflx4.initBytes(33, 33, 33, 255);
    _ = ecs.set(
        game.state.world,
        c_hrz,
        components.shape.Color,
        components.shape.Color.fromVec(cr_c),
    );
    _ = ecs.set(game.state.world, c_hrz, components.shape.Scale, .{ .x = 0.025, .y = 0.004, .z = 1 });
    _ = ecs.set(game.state.world, c_hrz, components.shape.Translation, .{ .x = -0.5, .y = -0.5, .z = 0 });
    _ = ecs.add(game.state.world, c_hrz, components.shape.NeedsSetup);
    ecs.add_pair(game.state.world, c_hrz, ecs.ChildOf, gameData);
    const c_vrt = helpers.new_child(game.state.world, game.state.entities.crosshair);
    _ = ecs.add(game.state.world, c_vrt, components.shape.Shape);
    _ = ecs.set(
        game.state.world,
        c_vrt,
        components.shape.Color,
        components.shape.Color.fromVec(cr_c),
    );
    _ = ecs.set(game.state.world, c_vrt, components.shape.Scale, .{ .x = 0.0025, .y = 0.04, .z = 1 });
    _ = ecs.set(game.state.world, c_vrt, components.shape.Translation, .{ .x = -0.5, .y = -0.5, .z = 0 });
    _ = ecs.add(game.state.world, c_vrt, components.shape.NeedsSetup);
    ecs.add_pair(game.state.world, c_vrt, ecs.ChildOf, gameData);
}

fn initFloor(gameData: ecs.entity_t) void {
    game.state.entities.floor = ecs.new_entity(game.state.world, "WorldFloor");
    const c_f = helpers.new_child(game.state.world, game.state.entities.floor);
    _ = ecs.add(game.state.world, c_f, components.shape.Shape);
    const cr_c = math.vecs.Vflx4.initBytes(34, 32, 52, 255);
    _ = ecs.set(
        game.state.world,
        c_f,
        components.shape.Color,
        components.shape.Color.fromVec(cr_c),
    );
    _ = ecs.set(game.state.world, c_f, components.shape.Scale, .{ .x = 0.33, .y = 0.5, .z = 1 });
    _ = ecs.set(game.state.world, c_f, components.shape.Translation, .{ .x = -0.5, .y = -0.5, .z = 0 });
    _ = ecs.set(game.state.world, c_f, components.shape.UBO, .{ .binding_point = GameUBOBindingPoint });
    _ = ecs.set(game.state.world, c_f, components.screen.WorldLocation, .{ .x = 0, .y = 0.25, .z = -1 });
    _ = ecs.add(game.state.world, c_f, components.shape.NeedsSetup);
    _ = ecs.add(game.state.world, c_f, components.Debug);
    ecs.add_pair(game.state.world, c_f, ecs.ChildOf, gameData);
}

fn initCamera(gameData: ecs.entity_t) void {
    game.state.entities.game_camera = ecs.new_entity(game.state.world, "GameCamera");
    const camera = helpers.new_child(game.state.world, game.state.entities.floor);
    _ = ecs.add(game.state.world, camera, components.screen.Camera);
    _ = ecs.set(game.state.world, camera, components.screen.CameraPosition, .{ .x = -68.0, .y = 78.0, .z = -70, .w = 1.0 });
    _ = ecs.set(game.state.world, camera, components.screen.CameraFront, .{ .x = 0.459, .y = -0.31, .z = 0.439, .w = 0 });
    _ = ecs.set(game.state.world, camera, components.screen.CameraRotation, .{ .yaw = 41.6, .pitch = -19.4 });
    _ = ecs.set(game.state.world, camera, components.screen.UpDirection, .{ .x = 0, .y = 1.0, .z = 0, .w = 0 });
    // These dimensions should also be component data to support monitors other than the one I've been working with:
    const h: gl.Float = @floatFromInt(config.windows_height);
    const w: gl.Float = @floatFromInt(config.windows_width);
    _ = ecs.set(game.state.world, camera, components.screen.Perspective, .{
        .fovy = config.fov,
        .aspect = w / h,
        .near = config.near,
        .far = config.far,
    });
    _ = ecs.add(game.state.world, camera, components.screen.Updated);
    ecs.add_pair(game.state.world, camera, ecs.ChildOf, gameData);
    // const ps = zm.perspectiveFovRh(config.fov, aspect, config.near, config.far);
    // zm.storeMat(&projection, ps);
}
