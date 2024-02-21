const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const zm = @import("zmath");
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");
const config = @import("../../config.zig");
const components = @import("../components/components.zig");
const helpers = @import("../helpers.zig");

pub const GameUBOBindingPoint: gl.Uint = 0;
var game_data: ecs.entity_t = undefined;
var settings_data: ecs.entity_t = undefined;

pub fn init() void {
    game.state.entities.screen = ecs.new_entity(game.state.world, "Screen");
    game_data = ecs.new_entity(game.state.world, "ScreenGameData");
    settings_data = ecs.new_entity(game.state.world, "ScreenSettingsData");
    const initialScreen = helpers.new_child(game.state.world, game.state.entities.screen);
    _ = ecs.add(game.state.world, initialScreen, components.screen.Game);
    _ = ecs.set(game.state.world, game.state.entities.screen, components.screen.Screen, .{
        .current = initialScreen,
        .gameDataEntity = game_data,
        .settingDataEntity = settings_data,
    });

    initCrossHairs();
    initFloor();
    initCamera();
    initCursor();
}

fn initCrossHairs() void {
    game.state.entities.crosshair = ecs.new_entity(game.state.world, "Crosshair");
    const c_hrz = helpers.new_child(game.state.world, game.state.entities.crosshair);
    _ = ecs.set(game.state.world, c_hrz, components.shape.Shape, .{ .shape_type = .plane });
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
    ecs.add_pair(game.state.world, c_hrz, ecs.ChildOf, game_data);
    const c_vrt = helpers.new_child(game.state.world, game.state.entities.crosshair);
    _ = ecs.set(game.state.world, c_vrt, components.shape.Shape, .{ .shape_type = .plane });
    _ = ecs.set(
        game.state.world,
        c_vrt,
        components.shape.Color,
        components.shape.Color.fromVec(cr_c),
    );
    _ = ecs.set(game.state.world, c_vrt, components.shape.Scale, .{ .x = 0.0025, .y = 0.04, .z = 1 });
    _ = ecs.set(game.state.world, c_vrt, components.shape.Translation, .{ .x = -0.5, .y = -0.5, .z = 0 });
    _ = ecs.add(game.state.world, c_vrt, components.shape.NeedsSetup);
    ecs.add_pair(game.state.world, c_vrt, ecs.ChildOf, game_data);
}

fn initFloor() void {
    game.state.entities.floor = ecs.new_entity(game.state.world, "WorldFloor");
    const c_f = helpers.new_child(game.state.world, game.state.entities.floor);
    _ = ecs.set(game.state.world, c_f, components.shape.Shape, .{ .shape_type = .plane });
    const cr_c = math.vecs.Vflx4.initBytes(34, 32, 52, 255);
    _ = ecs.set(
        game.state.world,
        c_f,
        components.shape.Color,
        components.shape.Color.fromVec(cr_c),
    );
    _ = ecs.set(game.state.world, c_f, components.shape.Scale, .{ .x = 500, .y = 500, .z = 500 });
    _ = ecs.set(game.state.world, c_f, components.shape.Translation, .{ .x = -0.5, .y = -0.5, .z = 0 });
    const floor_rot = zm.matToQuat(zm.rotationX(1.5 * std.math.pi));
    _ = ecs.set(game.state.world, c_f, components.shape.Rotation, .{
        .w = floor_rot[0],
        .x = floor_rot[1],
        .y = floor_rot[2],
        .z = floor_rot[3],
    });
    _ = ecs.set(game.state.world, c_f, components.shape.UBO, .{ .binding_point = GameUBOBindingPoint });
    _ = ecs.set(game.state.world, c_f, components.screen.WorldLocation, .{ .x = -25, .y = -25, .z = -25 });
    _ = ecs.add(game.state.world, c_f, components.shape.NeedsSetup);
    ecs.add_pair(game.state.world, c_f, ecs.ChildOf, game_data);
}

fn initCamera() void {
    const camera = ecs.new_entity(game.state.world, "GameCamera");
    game.state.entities.game_camera = camera;
    _ = ecs.add(game.state.world, camera, components.screen.Camera);
    _ = ecs.set(game.state.world, camera, components.screen.CameraPosition, .{ .pos = @Vector(4, gl.Float){ 1.0, 1.0, 1.0, 1.0 } });
    _ = ecs.set(game.state.world, camera, components.screen.CameraFront, .{ .front = @Vector(4, gl.Float){ 0.459, -0.31, 0.439, 0.0 } });
    _ = ecs.set(game.state.world, camera, components.screen.CameraRotation, .{ .yaw = 41.6, .pitch = -19.4 });
    _ = ecs.set(game.state.world, camera, components.screen.UpDirection, .{ .up = @Vector(4, gl.Float){ 0.0, 1.0, 0.0, 0.0 } });
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
    ecs.add_pair(game.state.world, camera, ecs.ChildOf, game_data);
}

fn initCursor() void {
    _ = ecs.add(game.state.world, game_data, components.screen.Cursor);
}

pub fn initDemoCube() void {
    var it = ecs.children(game.state.world, settings_data);
    while (ecs.iter_next(&it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            _ = ecs.add(game.state.world, entity, components.gfx.NeedsDeletion);
        }
    }
    const c_dc = helpers.new_child(game.state.world, settings_data);
    _ = ecs.set(game.state.world, c_dc, components.shape.Shape, .{ .shape_type = .plane });
    var cr_c = math.vecs.Vflx4.initBytes(255, 0, 255, 255);
    const div: i64 = 100;
    const time = std.time.milliTimestamp();
    const offset: i64 = @mod(time, div);
    const hue: f32 = @as(f32, @floatFromInt(offset)) / @as(f32, @floatFromInt(div));
    cr_c.setHue(hue);
    _ = ecs.set(
        game.state.world,
        c_dc,
        components.shape.Color,
        components.shape.Color.fromVec(cr_c),
    );
    _ = ecs.set(game.state.world, c_dc, components.shape.Scale, .{ .x = 0.25, .y = 0.25, .z = 0.25 });
    _ = ecs.set(game.state.world, c_dc, components.shape.Translation, .{ .x = -3.75, .y = 2, .z = 0 });
    _ = ecs.add(game.state.world, c_dc, components.shape.NeedsSetup);
    _ = ecs.add(game.state.world, c_dc, components.Debug);
}
