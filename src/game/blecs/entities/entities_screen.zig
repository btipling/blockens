const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl").bindings;
const zm = @import("zmath");
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");
const config = @import("../../config.zig");
const components = @import("../components/components.zig");
const helpers = @import("../helpers.zig");
const chunk = @import("../../chunk.zig");

pub const GameUBOBindingPoint: gl.Uint = 0;
pub const SettingsUBOBindingPoint: gl.Uint = 1;
pub const DemoCubeAnimationBindingPoint: gl.Uint = 2;

pub var game_data: ecs.entity_t = undefined;
pub var settings_data: ecs.entity_t = undefined;

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
    initSettingsCamera();
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
    const p_x_ratio: gl.Float = 0.6666;
    _ = ecs.set(game.state.world, c_hrz, components.shape.Scale, .{
        .scale = @Vector(4, gl.Float){
            0.004 * p_x_ratio,
            0.04,
            1,
            0,
        },
    });
    _ = ecs.set(game.state.world, c_hrz, components.shape.Translation, .{
        .translation = @Vector(4, gl.Float){
            0,
            -0.018,
            0,
            0,
        },
    });
    _ = ecs.add(game.state.world, c_hrz, components.shape.NeedsSetup);
    ecs.add_pair(game.state.world, c_hrz, ecs.ChildOf, game_data);
    const c_vrt = helpers.new_child(game.state.world, game.state.entities.crosshair);
    _ = ecs.set(game.state.world, c_vrt, components.shape.Shape, .{ .shape_type = .plane });
    const cr_c2 = math.vecs.Vflx4.initBytes(33, 33, 33, 255);
    _ = ecs.set(
        game.state.world,
        c_vrt,
        components.shape.Color,
        components.shape.Color.fromVec(cr_c2),
    );
    _ = ecs.set(game.state.world, c_vrt, components.shape.Scale, .{
        .scale = @Vector(4, gl.Float){
            0.04 * p_x_ratio,
            0.004,
            1,
            0,
        },
    });
    _ = ecs.set(game.state.world, c_vrt, components.shape.Translation, .{
        .translation = @Vector(4, gl.Float){
            -0.018 * p_x_ratio,
            0,
            0,
            0,
        },
    });
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
    _ = ecs.set(game.state.world, c_f, components.shape.Scale, .{
        .scale = @Vector(4, gl.Float){ 500, 500, 500, 0 },
    });
    _ = ecs.set(game.state.world, c_f, components.shape.Translation, .{
        .translation = @Vector(4, gl.Float){ -0.5, -0.5, 20, 0 },
    });
    const floor_rot = zm.matToQuat(zm.rotationX(1.5 * std.math.pi));
    _ = ecs.set(game.state.world, c_f, components.shape.Rotation, .{
        .rot = floor_rot,
    });
    _ = ecs.set(game.state.world, c_f, components.shape.UBO, .{ .binding_point = GameUBOBindingPoint });
    _ = ecs.set(game.state.world, c_f, components.screen.WorldLocation, .{
        .loc = @Vector(4, gl.Float){ -25, -25, -25, 0 },
    });
    _ = ecs.add(game.state.world, c_f, components.shape.NeedsSetup);
    _ = ecs.add(game.state.world, c_f, components.Debug);
    ecs.add_pair(game.state.world, c_f, ecs.ChildOf, game_data);
}

fn initCamera() void {
    const camera = ecs.new_entity(game.state.world, "GameCamera");
    game.state.entities.game_camera = camera;
    _ = ecs.set(game.state.world, camera, components.screen.Camera, .{ .ubo = GameUBOBindingPoint });
    _ = ecs.set(game.state.world, camera, components.screen.CameraPosition, .{ .pos = @Vector(4, gl.Float){ 1.0, 1.0, 1.0, 1.0 } });
    _ = ecs.set(game.state.world, camera, components.screen.CameraFront, .{ .front = @Vector(4, gl.Float){ 0.03, -0.155, -0.7, 0.0 } });
    _ = ecs.set(game.state.world, camera, components.screen.CameraRotation, .{ .yaw = -90, .pitch = -19.4 });
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

fn initSettingsCamera() void {
    const camera = ecs.new_entity(game.state.world, "SettingsCamera");
    game.state.entities.settings_camera = camera;
    _ = ecs.set(game.state.world, camera, components.screen.Camera, .{ .ubo = SettingsUBOBindingPoint });
    _ = ecs.set(game.state.world, camera, components.screen.CameraPosition, .{ .pos = @Vector(4, gl.Float){ -8, 0, 0.0, 0.0 } });
    _ = ecs.set(game.state.world, camera, components.screen.CameraFront, .{ .front = @Vector(4, gl.Float){ 1, 0, 0, 0.0 } });
    _ = ecs.set(game.state.world, camera, components.screen.CameraRotation, .{ .yaw = 0, .pitch = 0 });
    _ = ecs.set(game.state.world, camera, components.screen.UpDirection, .{ .up = @Vector(4, gl.Float){ 0.0, 1.0, 0.0, 0.0 } });
    const h: gl.Float = @floatFromInt(config.windows_height);
    const w: gl.Float = @floatFromInt(config.windows_width);
    _ = ecs.set(game.state.world, camera, components.screen.Perspective, .{
        .fovy = config.fov,
        .aspect = w / h,
        .near = config.near,
        .far = config.far,
    });
    _ = ecs.add(game.state.world, camera, components.screen.Updated);
    ecs.add_pair(game.state.world, camera, ecs.ChildOf, settings_data);
}

pub fn clearDemoObjects() void {
    const world = game.state.world;
    var it = ecs.children(world, settings_data);
    while (ecs.iter_next(&it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            _ = ecs.add(world, entity, components.gfx.NeedsDeletion);
        }
    }
}

pub fn initDemoCube() void {
    if (game.state.ui.data.texture_rgba_data == null) {
        return;
    }
    const world = game.state.world;
    clearDemoObjects();
    const c_dc = helpers.new_child(world, settings_data);
    _ = ecs.set(world, c_dc, components.shape.Shape, .{ .shape_type = .cube });
    const cr_c = math.vecs.Vflx4.initBytes(0, 0, 0, 0);
    _ = ecs.set(world, c_dc, components.shape.Color, components.shape.Color.fromVec(cr_c));
    _ = ecs.set(world, c_dc, components.shape.UBO, .{ .binding_point = SettingsUBOBindingPoint });
    _ = ecs.set(world, c_dc, components.shape.Rotation, .{
        .rot = game.state.ui.data.demo_cube_rotation,
    });
    _ = ecs.set(world, c_dc, components.shape.Translation, .{
        .translation = game.state.ui.data.demo_cube_translation,
    });
    _ = ecs.set(world, c_dc, components.shape.DemoCubeTexture, .{ .beg = 0, .end = 16 * 16 * 3 });
    _ = ecs.add(world, c_dc, components.shape.NeedsSetup);
    _ = ecs.add(world, c_dc, components.Debug);
    _ = ecs.set(world, game.state.entities.settings_camera, components.screen.PostPerspective, .{
        .translation = game.state.ui.data.demo_cube_pp_translation,
    });
    // Add animation to cube:
    const animation = helpers.new_child(world, c_dc);
    _ = ecs.set(world, animation, components.gfx.AnimationSSBO, .{
        .ssbo = DemoCubeAnimationBindingPoint,
    });

    const kf0 = ecs.new_id(world);
    _ = ecs.set(world, kf0, components.gfx.AnimationKeyFrame, .{
        .translation = @Vector(4, gl.Float){ 0, 0, 0, 0 },
        .rotation = @Vector(4, gl.Float){ 0.17867, 0.899888, 0.240292, -0.317079 },
    });
    const kf1 = ecs.new_id(world);
    _ = ecs.set(world, kf1, components.gfx.AnimationKeyFrame, .{
        .translation = @Vector(4, gl.Float){ 0, 0, 0, 0 },
        .rotation = @Vector(4, gl.Float){ -0.461112, -0.353858, -0.100431, 0.808 },
    });
    const kf2 = ecs.new_id(world);
    _ = ecs.set(world, kf2, components.gfx.AnimationKeyFrame, .{
        .translation = @Vector(4, gl.Float){ 0, 0, 0, 0 },
        .rotation = @Vector(4, gl.Float){ -0.264643, -0.450094, 0.140096, -0.84128 },
    });
    const kf3 = ecs.new_id(world);
    _ = ecs.set(world, kf3, components.gfx.AnimationKeyFrame, .{
        .translation = @Vector(4, gl.Float){ 0, 0, 0, 0 },
        .rotation = @Vector(4, gl.Float){ 0.056235, -0.646945, 0.46856, -0.598959 },
    });
    ecs.add_pair(world, kf0, ecs.ChildOf, animation);
    ecs.add_pair(world, kf1, ecs.ChildOf, animation);
    ecs.add_pair(world, kf2, ecs.ChildOf, animation);
    ecs.add_pair(world, kf3, ecs.ChildOf, animation);

    const p_x_ratio: gl.Float = 0.6666;
    const p_scale: gl.Float = 0.3;
    const c_t1 = helpers.new_child(world, settings_data);
    _ = ecs.set(world, c_t1, components.shape.Shape, .{ .shape_type = .plane });
    _ = ecs.set(world, c_t1, components.shape.Color, components.shape.Color.fromVec(cr_c));
    _ = ecs.set(world, c_t1, components.shape.Scale, .{ .scale = @Vector(4, gl.Float){ p_scale * p_x_ratio, p_scale, p_scale, 0 } });
    _ = ecs.set(world, c_t1, components.shape.Translation, .{ .translation = game.state.ui.data.demo_cube_plane_1_tl });
    _ = ecs.set(world, c_t1, components.shape.DemoCubeTexture, .{ .beg = 0, .end = 16 * 16 });
    _ = ecs.add(world, c_t1, components.shape.NeedsSetup);

    const c_t2 = helpers.new_child(world, settings_data);
    _ = ecs.set(world, c_t2, components.shape.Shape, .{ .shape_type = .plane });
    _ = ecs.set(world, c_t2, components.shape.Color, components.shape.Color.fromVec(cr_c));
    _ = ecs.set(world, c_t2, components.shape.Scale, .{ .scale = @Vector(4, gl.Float){ p_scale * p_x_ratio, p_scale, p_scale, 0 } });
    _ = ecs.set(world, c_t2, components.shape.Translation, .{ .translation = game.state.ui.data.demo_cube_plane_1_t2 });
    _ = ecs.set(world, c_t2, components.shape.DemoCubeTexture, .{ .beg = 16 * 16, .end = 16 * 16 * 2 });
    _ = ecs.set(world, c_t2, components.shape.Rotation, .{
        .rot = zm.matToQuat(zm.rotationZ(1 * std.math.pi)),
    });
    _ = ecs.add(world, c_t2, components.shape.NeedsSetup);
    ecs.add_pair(world, c_t2, ecs.ChildOf, settings_data);

    const c_t3 = helpers.new_child(world, settings_data);
    _ = ecs.set(world, c_t3, components.shape.Shape, .{ .shape_type = .plane });
    _ = ecs.set(world, c_t3, components.shape.Color, components.shape.Color.fromVec(cr_c));
    _ = ecs.set(world, c_t3, components.shape.Scale, .{ .scale = @Vector(4, gl.Float){ p_scale * p_x_ratio, p_scale, p_scale, 0 } });
    _ = ecs.set(world, c_t3, components.shape.Translation, .{ .translation = game.state.ui.data.demo_cube_plane_1_t3 });
    _ = ecs.set(world, c_t3, components.shape.DemoCubeTexture, .{ .beg = 16 * 16 * 2, .end = 16 * 16 * 3 });
    _ = ecs.add(world, c_t3, components.shape.NeedsSetup);
}

pub fn initDemoChunk() void {
    if (game.state.ui.data.chunk_demo_data == null) {
        return;
    }
    const world = game.state.world;
    const allocator = game.state.allocator;
    // TODO chunk data needs to be u32s...
    const chunk_data: []i32 = game.state.ui.data.chunk_demo_data.?;
    var block_instance_map = std.AutoArrayHashMapUnmanaged(u8, ecs.entity_t){};
    defer block_instance_map.deinit(allocator);
    const chunk_demo_data = game.state.ui.data.chunk_demo_data.?;
    std.debug.print("chunk len: {d}\n", .{chunk_demo_data.len});

    var block_id: u8 = 0;
    for (0..chunk_data.len) |i| {
        if (chunk_data[i] == 0) continue;
        block_id = @intCast(chunk_data[i]);
        if (!block_instance_map.contains(block_id)) {
            const block_entity = helpers.new_child(world, settings_data);
            ecs.add(world, block_entity, components.block.BlockInstances);
            _ = ecs.set(world, block_entity, components.shape.Shape, .{ .shape_type = .cube });
            _ = ecs.set(world, block_entity, components.block.Block, .{
                .block_id = block_id,
            });
            ecs.add(world, block_entity, components.shape.NeedsSetup);
            block_instance_map.put(allocator, block_id, block_entity) catch unreachable;
        }
        const block_entity: ecs.entity_t = block_instance_map.get(block_id).?;
        // We're going to make a lot of instances, if ecs is not performant, will need different strategy
        const block_instance = helpers.new_child(world, block_entity);
        // block instances are not shapes, their parent is.
        ecs.add(world, block_instance, components.block.BlockInstance);
        const pos = chunk.getPositionAtIndexV(i);
        _ = ecs.set(world, block_instance, components.shape.Position, .{ .position = pos });
        break; // Just do draw block for now.
    }
}
