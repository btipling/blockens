pub var game_data: ecs.entity_t = undefined;
pub var settings_data: ecs.entity_t = undefined;

pub fn init() void {
    game.state.entities.screen = ecs.new_entity(game.state.world, "Screen");
    game_data = ecs.new_entity(game.state.world, "ScreenGameData");
    settings_data = ecs.new_entity(game.state.world, "ScreenSettingsData");
    const initialScreen = helpers.new_child(game.state.world, game.state.entities.screen);
    ecs.add(game.state.world, initialScreen, components.screen.Game);
    _ = ecs.set(game.state.world, game.state.entities.screen, components.screen.Screen, .{
        .current = initialScreen,
        .gameDataEntity = game_data,
        .settingDataEntity = settings_data,
    });

    initCrossHairs();
    // initFloor();
    initCameras();
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
    const p_x_ratio: f32 = 0.6666;
    _ = ecs.set(game.state.world, c_hrz, components.shape.Scale, .{
        .scale = @Vector(4, f32){
            0.004 * p_x_ratio,
            0.04,
            1,
            0,
        },
    });
    _ = ecs.set(game.state.world, c_hrz, components.shape.Translation, .{
        .translation = @Vector(4, f32){
            0,
            -0.018,
            0,
            0,
        },
    });
    ecs.add(game.state.world, c_hrz, components.shape.NeedsSetup);
    ecs.add(game.state.world, c_hrz, components.shape.Permanent);
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
        .scale = @Vector(4, f32){
            0.04 * p_x_ratio,
            0.004,
            1,
            0,
        },
    });
    _ = ecs.set(game.state.world, c_vrt, components.shape.Translation, .{
        .translation = @Vector(4, f32){
            -0.018 * p_x_ratio,
            0,
            0,
            0,
        },
    });
    ecs.add(game.state.world, c_vrt, components.shape.NeedsSetup);
    ecs.add(game.state.world, c_vrt, components.shape.Permanent);
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
        .scale = @Vector(4, f32){ 500, 500, 500, 0 },
    });
    _ = ecs.set(game.state.world, c_f, components.shape.Translation, .{
        .translation = @Vector(4, f32){ -0.5, -0.5, 20, 0 },
    });
    const floor_rot = zm.matToQuat(zm.rotationX(1.5 * std.math.pi));
    _ = ecs.set(game.state.world, c_f, components.shape.Rotation, .{
        .rot = floor_rot,
    });
    _ = ecs.set(game.state.world, c_f, components.shape.UBO, .{ .binding_point = gfx.constants.GameUBOBindingPoint });
    _ = ecs.set(game.state.world, c_f, components.screen.WorldLocation, .{
        .loc = @Vector(4, f32){ -25, -25, -25, 0 },
    });
    ecs.add(game.state.world, c_f, components.shape.NeedsSetup);
    ecs.add(game.state.world, c_f, components.shape.Permanent);
    ecs.add_pair(game.state.world, c_f, ecs.ChildOf, game_data);
}

fn initCameras() void {
    // sky cam
    const sky_camera = ecs.new_entity(game.state.world, "SkyCamera");
    game.state.entities.sky_camera = sky_camera;
    _ = ecs.set(game.state.world, sky_camera, components.screen.Camera, .{ .ubo = gfx.constants.GameUBOBindingPoint });
    _ = ecs.set(game.state.world, sky_camera, components.screen.CameraPosition, .{
        .pos = @Vector(4, f32){ 62, 81, 63, 1.0 },
    });
    _ = ecs.set(game.state.world, sky_camera, components.screen.CameraFront, .{
        .front = @Vector(4, f32){ -0.417, -0.398, -0.409, 0.0 },
    });
    _ = ecs.set(
        game.state.world,
        sky_camera,
        components.screen.CameraRotation,
        .{ .yaw = -496, .pitch = -34.3 },
    );
    _ = ecs.set(game.state.world, sky_camera, components.screen.UpDirection, .{
        .up = @Vector(4, f32){ 0.0, 1.0, 0.0, 0.0 },
    });
    // These dimensions should also be component data to support monitors other than the one I've been working with:
    const w: f32 = game.state.ui.screen_size[0];
    const h: f32 = game.state.ui.screen_size[1];
    _ = ecs.set(game.state.world, sky_camera, components.screen.Perspective, .{
        .fovy = config.fov,
        .aspect = w / h,
        .near = config.near,
        .far = config.far,
    });
    ecs.add(game.state.world, sky_camera, components.screen.CurrentCamera);
    ecs.add(game.state.world, sky_camera, components.screen.Updated);
    ecs.add_pair(game.state.world, sky_camera, ecs.ChildOf, game_data);

    // third person cam
    const tpc = ecs.new_entity(game.state.world, "ThirdPersonCamera");
    game.state.entities.third_person_camera = tpc;
    _ = ecs.set(game.state.world, tpc, components.screen.Camera, .{ .ubo = gfx.constants.GameUBOBindingPoint });
    _ = ecs.set(game.state.world, tpc, components.screen.CameraPosition, .{
        .pos = @Vector(4, f32){ 0, 0, 0, 1.0 },
    });
    _ = ecs.set(game.state.world, tpc, components.screen.CameraFront, .{
        .front = @Vector(4, f32){ 0.1, -0.08, 0.1, 0.0 },
    });
    _ = ecs.set(
        game.state.world,
        tpc,
        components.screen.CameraRotation,
        .{ .yaw = 0, .pitch = 0 },
    );
    _ = ecs.set(game.state.world, tpc, components.screen.UpDirection, .{
        .up = @Vector(4, f32){ 0.0, 1.0, 0.0, 0.0 },
    });
    _ = ecs.set(game.state.world, tpc, components.screen.Perspective, .{
        .fovy = config.fov,
        .aspect = w / h,
        .near = config.near,
        .far = config.far,
    });
    ecs.add_pair(game.state.world, tpc, ecs.ChildOf, game_data);
}

fn initCursor() void {
    ecs.add(game.state.world, game_data, components.screen.Cursor);
}

fn initSettingsCamera() void {
    const world = game.state.world;
    const camera = ecs.new_entity(world, "SettingsCamera");
    game.state.entities.settings_camera = camera;
    _ = ecs.set(world, camera, components.screen.Camera, .{ .ubo = gfx.constants.SettingsUBOBindingPoint });
    _ = ecs.set(world, camera, components.screen.CameraPosition, .{ .pos = @Vector(4, f32){ -8, 0, 0.0, 0.0 } });
    _ = ecs.set(world, camera, components.screen.CameraFront, .{ .front = @Vector(4, f32){ 1, 0, 0, 0.0 } });
    _ = ecs.set(world, camera, components.screen.CameraRotation, .{ .yaw = 0, .pitch = 0 });
    _ = ecs.set(world, camera, components.screen.UpDirection, .{ .up = @Vector(4, f32){ 0.0, 1.0, 0.0, 0.0 } });
    const w: f32 = game.state.ui.screen_size[0];
    const h: f32 = game.state.ui.screen_size[1];
    _ = ecs.set(world, camera, components.screen.Perspective, .{
        .fovy = config.fov,
        .aspect = w / h,
        .near = config.near,
        .far = config.far,
    });
    ecs.add(world, camera, components.screen.CurrentCamera);
    ecs.add(world, camera, components.screen.Updated);
    ecs.add_pair(world, camera, ecs.ChildOf, settings_data);
}

pub fn toggleCamera() void {
    const world = game.state.world;
    const sky_cam = game.state.entities.sky_camera;
    const tpc = game.state.entities.third_person_camera;
    if (ecs.has_id(world, sky_cam, ecs.id(components.screen.CurrentCamera))) {
        ecs.remove(world, sky_cam, components.screen.CurrentCamera);
        ecs.add(world, tpc, components.screen.CurrentCamera);
        return;
    }
    ecs.remove(world, tpc, components.screen.CurrentCamera);
    ecs.add(world, sky_cam, components.screen.CurrentCamera);
}

pub fn getCurrentCamera() ecs.entity_t {
    const world = game.state.world;
    const sky_cam = game.state.entities.sky_camera;
    const tpc = game.state.entities.third_person_camera;
    if (ecs.has_id(world, sky_cam, ecs.id(components.screen.CurrentCamera))) {
        return sky_cam;
    }
    return tpc;
}

pub fn setThirdPersonCamera() void {
    const world = game.state.world;
    const tpc = game.state.entities.third_person_camera;
    const cc = getCurrentCamera();
    if (cc == tpc) return;
    ecs.remove(world, cc, components.screen.CurrentCamera);
    ecs.add(world, tpc, components.screen.CurrentCamera);
}

pub fn clearWorld() void {
    const world = game.state.world;
    var it = ecs.children(world, game_data);
    while (ecs.iter_next(&it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            if (ecs.has_id(world, entity, ecs.id(components.shape.Permanent))) {
                continue;
            }
            if (!ecs.has_id(world, entity, ecs.id(components.shape.Shape))) {
                continue;
            }
            ecs.add(world, entity, components.gfx.NeedsDeletion);
        }
    }
    ecs.remove(world, game.state.entities.sky_camera, components.screen.WorldTranslation);
    ecs.remove(world, game.state.entities.sky_camera, components.screen.WorldRotation);
    ecs.remove(world, game.state.entities.sky_camera, components.screen.WorldScale);
    ecs.remove(world, game.state.entities.sky_camera, components.screen.PostPerspective);
}

pub fn clearDemoObjects() void {
    const world = game.state.world;
    var it = ecs.children(world, settings_data);
    while (ecs.iter_next(&it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            ecs.add(world, entity, components.gfx.NeedsDeletion);
        }
    }
    ecs.remove(world, game.state.entities.settings_camera, components.screen.WorldTranslation);
    ecs.remove(world, game.state.entities.settings_camera, components.screen.WorldRotation);
    ecs.remove(world, game.state.entities.settings_camera, components.screen.WorldScale);
    ecs.remove(world, game.state.entities.settings_camera, components.screen.PostPerspective);
}

pub fn initDemoCube() void {
    if (game.state.ui.texture_rgba_data == null) {
        return;
    }
    const world = game.state.world;
    clearDemoObjects();

    // Demo cube needs a little camera adjustment to be on the left side of the screen while keeping
    // the perspective centered at it.
    _ = ecs.set(world, game.state.entities.settings_camera, components.screen.PostPerspective, .{
        .translation = game.state.ui.demo_cube_pp_translation,
    });

    const c_dc = helpers.new_child(world, settings_data);
    _ = ecs.set(world, c_dc, components.shape.Shape, .{ .shape_type = .cube });
    const cr_c = math.vecs.Vflx4.initBytes(0, 0, 0, 0);
    _ = ecs.set(world, c_dc, components.shape.Color, components.shape.Color.fromVec(cr_c));
    _ = ecs.set(world, c_dc, components.shape.UBO, .{ .binding_point = gfx.constants.SettingsUBOBindingPoint });
    _ = ecs.set(world, c_dc, components.shape.Rotation, .{
        .rot = game.state.ui.demo_cube_rotation,
    });
    _ = ecs.set(world, c_dc, components.shape.Translation, .{
        .translation = game.state.ui.demo_cube_translation,
    });
    _ = ecs.set(world, c_dc, components.shape.DemoCubeTexture, .{ .beg = 0, .end = 16 * 16 * 3 });
    ecs.add(world, c_dc, components.shape.NeedsSetup);
    // Add animation to cube:
    const animation = helpers.new_child(world, c_dc);
    _ = ecs.set(world, animation, components.gfx.AnimationMesh, .{
        .animation_id = gfx.constants.DemoCubeAnimationID,
    });

    const kf0 = ecs.new_id(world);
    _ = ecs.set(world, kf0, components.gfx.AnimationKeyFrame, .{
        .frame = 0,
        .translation = @Vector(4, f32){ 0, 0, 0, 0 },
        .rotation = @Vector(4, f32){ 0.17867, 0.899888, 0.240292, -0.317079 },
    });
    const kf1 = ecs.new_id(world);
    _ = ecs.set(world, kf1, components.gfx.AnimationKeyFrame, .{
        .frame = 1,
        .translation = @Vector(4, f32){ 0, 0, 0, 0 },
        .rotation = @Vector(4, f32){ -0.461112, -0.353858, -0.100431, 0.808 },
    });
    const kf2 = ecs.new_id(world);
    _ = ecs.set(world, kf2, components.gfx.AnimationKeyFrame, .{
        .frame = 2,
        .translation = @Vector(4, f32){ 0, 0, 0, 0 },
        .rotation = @Vector(4, f32){ -0.264643, -0.450094, 0.140096, -0.84128 },
    });
    const kf3 = ecs.new_id(world);
    _ = ecs.set(world, kf3, components.gfx.AnimationKeyFrame, .{
        .frame = 3,
        .translation = @Vector(4, f32){ 0, 0, 0, 0 },
        .rotation = @Vector(4, f32){ 0.056235, -0.646945, 0.46856, -0.598959 },
    });
    const kf4 = ecs.new_id(world);
    _ = ecs.set(world, kf4, components.gfx.AnimationKeyFrame, .{
        .frame = 4,
        .translation = @Vector(4, f32){ 0, 0, 0, 0 },
        .rotation = @Vector(4, f32){ 0.17867, 0.899888, 0.240292, -0.317079 },
    });
    ecs.add_pair(world, kf0, ecs.ChildOf, animation);
    ecs.add_pair(world, kf1, ecs.ChildOf, animation);
    ecs.add_pair(world, kf2, ecs.ChildOf, animation);
    ecs.add_pair(world, kf3, ecs.ChildOf, animation);
    ecs.add_pair(world, kf4, ecs.ChildOf, animation);

    const p_x_ratio: f32 = 0.6666;
    const p_scale: f32 = 0.3;
    const c_t1 = helpers.new_child(world, settings_data);
    _ = ecs.set(world, c_t1, components.shape.Shape, .{ .shape_type = .plane });
    _ = ecs.set(world, c_t1, components.shape.Color, components.shape.Color.fromVec(cr_c));
    _ = ecs.set(world, c_t1, components.shape.Scale, .{ .scale = @Vector(4, f32){ p_scale * p_x_ratio, p_scale, p_scale, 0 } });
    _ = ecs.set(world, c_t1, components.shape.Translation, .{ .translation = game.state.ui.demo_cube_plane_1_tl });
    _ = ecs.set(world, c_t1, components.shape.DemoCubeTexture, .{ .beg = 0, .end = 16 * 16 });
    ecs.add(world, c_t1, components.shape.NeedsSetup);

    const c_t2 = helpers.new_child(world, settings_data);
    _ = ecs.set(world, c_t2, components.shape.Shape, .{ .shape_type = .plane });
    _ = ecs.set(world, c_t2, components.shape.Color, components.shape.Color.fromVec(cr_c));
    _ = ecs.set(world, c_t2, components.shape.Scale, .{ .scale = @Vector(4, f32){ p_scale * p_x_ratio, p_scale, p_scale, 0 } });
    _ = ecs.set(world, c_t2, components.shape.Translation, .{ .translation = game.state.ui.demo_cube_plane_1_t2 });
    _ = ecs.set(world, c_t2, components.shape.DemoCubeTexture, .{ .beg = 16 * 16, .end = 16 * 16 * 2 });
    _ = ecs.set(world, c_t2, components.shape.Rotation, .{
        .rot = zm.matToQuat(zm.rotationZ(1 * std.math.pi)),
    });
    ecs.add(world, c_t2, components.shape.NeedsSetup);
    ecs.add_pair(world, c_t2, ecs.ChildOf, settings_data);

    const c_t3 = helpers.new_child(world, settings_data);
    _ = ecs.set(world, c_t3, components.shape.Shape, .{ .shape_type = .plane });
    _ = ecs.set(world, c_t3, components.shape.Color, components.shape.Color.fromVec(cr_c));
    _ = ecs.set(world, c_t3, components.shape.Scale, .{ .scale = @Vector(4, f32){ p_scale * p_x_ratio, p_scale, p_scale, 0 } });
    _ = ecs.set(world, c_t3, components.shape.Translation, .{ .translation = game.state.ui.demo_cube_plane_1_t3 });
    _ = ecs.set(world, c_t3, components.shape.DemoCubeTexture, .{ .beg = 16 * 16 * 2, .end = 16 * 16 * 3 });
    ecs.add(world, c_t3, components.shape.NeedsSetup);
    initDemoTextureAtlas();
}

pub fn initDemoTextureAtlas() void {
    const world = game.state.world;
    const cr_c = math.vecs.Vflx4.initFloats(0, 0, 1, 0);
    const c_atlas = helpers.new_child(world, settings_data);
    const color = components.shape.Color.fromVec(cr_c);
    std.debug.print("setting atlas color to ({d}, {d}, {d}, {d}) for entity {d}\n", .{
        color.color[0],
        color.color[1],
        color.color[2],
        color.color[3],
        c_atlas,
    });
    const atlas_rot = zm.rotationZ(game.state.ui.demo_atlas_rotation * std.math.pi * 2.0);
    _ = ecs.set(
        game.state.world,
        c_atlas,
        components.screen.WorldRotation,
        .{ .rotation = zm.matToQuat(atlas_rot) },
    );
    _ = ecs.set(world, c_atlas, components.shape.Shape, .{ .shape_type = .plane });
    _ = ecs.set(world, c_atlas, components.shape.Color, components.shape.Color.fromVec(cr_c));
    _ = ecs.set(world, c_atlas, components.shape.Scale, .{ .scale = game.state.ui.demo_atlas_scale });
    _ = ecs.set(world, c_atlas, components.shape.Translation, .{ .translation = game.state.ui.demo_atlas_translation });
    ecs.add(world, c_atlas, components.block.UseTextureAtlas);
    ecs.add(world, c_atlas, components.shape.NeedsSetup);
}

pub fn initDemoChunkCamera() void {
    const world = game.state.world;

    // Demo chunks also needs a camera adjustment to keep perspective centered on it
    const camera = game.state.entities.settings_camera;
    _ = ecs.set(world, camera, components.screen.PostPerspective, .{
        .translation = game.state.ui.demo_chunk_pp_translation,
    });
    const chunk_scale = game.state.ui.demo_chunk_scale;
    _ = ecs.set(
        world,
        camera,
        components.screen.WorldScale,
        .{ .scale = @Vector(4, f32){ chunk_scale, chunk_scale, chunk_scale, 0 } },
    );
    {
        // screen rotations reset to chunk rotation settings upon chunk camera init
        game.state.ui.demo_screen_rotation_y = game.state.ui.demo_chunk_rotation_y;
        game.state.ui.demo_screen_rotation_x = game.state.ui.demo_chunk_rotation_x;
        game.state.ui.demo_screen_rotation_z = game.state.ui.demo_chunk_rotation_z;
    }

    const chunk_rot = zm.quatFromRollPitchYaw(
        game.state.ui.demo_screen_rotation_x,
        game.state.ui.demo_screen_rotation_y,
        game.state.ui.demo_screen_rotation_z,
    );
    _ = ecs.set(
        game.state.world,
        camera,
        components.screen.WorldRotation,
        .{ .rotation = chunk_rot },
    );
    _ = ecs.set(
        world,
        camera,
        components.screen.WorldTranslation,
        .{ .translation = game.state.ui.demo_chunk_translation },
    );
}

pub fn initDemoChunk() void {
    if (game.state.ui.chunk_demo_data == null) {
        return;
    }
    clearDemoObjects();
    const world = game.state.world;
    initDemoChunkCamera();
    chunk.render.renderSettingsChunk(
        chunk.worldPosition.initFromPositionV(.{ 0, 0, 0, 0 }),
        ecs.new_id(world),
    );
    return;
}

pub fn initDemoCharacterCamera() void {
    const world = game.state.world;
    // Demo characters also needs a camera adjustment to keep perspective centered on it
    const camera = game.state.entities.settings_camera;
    _ = ecs.set(world, camera, components.screen.PostPerspective, .{
        .translation = game.state.ui.demo_character_pp_translation,
    });
    const character_scale = game.state.ui.demo_character_scale;
    _ = ecs.set(
        world,
        camera,
        components.screen.WorldScale,
        .{ .scale = @Vector(4, f32){ character_scale, character_scale, character_scale, 0 } },
    );
    {
        // screen rotations reset to character rotation settings upon character camera init
        game.state.ui.demo_screen_rotation_y = game.state.ui.demo_character_rotation_y;
        game.state.ui.demo_screen_rotation_x = game.state.ui.demo_character_rotation_x;
        game.state.ui.demo_screen_rotation_z = game.state.ui.demo_character_rotation_z;
    }
    const character_rot = zm.quatFromRollPitchYaw(
        game.state.ui.demo_screen_rotation_x,
        game.state.ui.demo_screen_rotation_y,
        game.state.ui.demo_screen_rotation_z,
    );
    _ = ecs.set(
        game.state.world,
        camera,
        components.screen.WorldRotation,
        .{ .rotation = character_rot },
    );
    _ = ecs.set(
        world,
        camera,
        components.screen.WorldTranslation,
        .{ .translation = game.state.ui.demo_character_translation },
    );
}

pub fn initDemoCharacter() void {
    std.debug.print("init demo character\n", .{});
    clearDemoObjects();
    initDemoCharacterCamera();
    const world = game.state.world;
    var player = game.state.entities.demo_player;
    if (player == 0) {
        player = ecs.new_entity(game.state.world, "DemoPlayer");
        game.state.entities.demo_player = player;
        _ = ecs.set(world, player, components.mob.Mob, .{
            .mob_id = 1,
            .data_entity = settings_data,
        });
        _ = ecs.set(world, player, components.mob.Position, .{
            .position = game.state.ui.demo_cube_translation,
        });
        const bounding_box = helpers.new_child(world, settings_data);
        ecs.add_pair(
            world,
            player,
            mob_entities.HasBoundingBox,
            bounding_box,
        );
        _ = ecs.set(
            world,
            bounding_box,
            components.mob.BoundingBox,
            .{ .mob_id = 1, .mob_entity = player },
        );
        const c = math.vecs.Vflx4.initBytes(255, 255, 255, 255);
        _ = ecs.set(
            world,
            bounding_box,
            components.shape.Outline,
            .{ .color = c.value },
        );
        _ = ecs.set(
            world,
            bounding_box,
            components.shape.Color,
            .{ .color = .{ 0, 0, 0, 0 } },
        );
        ecs.add(world, bounding_box, components.mob.NeedsSetup);
    }
    ecs.add(world, game.state.entities.demo_player, components.mob.NeedsSetup);
}

pub fn initPlayerCharacter() void {
    const world = game.state.world;
    const world_id = game.state.ui.world_loaded_id;
    const tpc = game.state.entities.third_person_camera;
    if (game.state.entities.player != 0) return;
    const player = ecs.new_entity(game.state.world, "Player");
    game.state.entities.player = player;

    var player_pos: data.Data.playerPosition = .{};
    game.state.db.loadPlayerPosition(world_id, &player_pos) catch |err| {
        std.debug.assert(err != data.DataErr.NotFound);
        @panic("SQL ERROR");
    };

    const rotation: components.mob.Rotation = .{
        .rotation = player_pos.rot,
        .angle = player_pos.angle,
    };
    {
        // Set player entity props.
        _ = ecs.set(world, player, components.mob.Mob, .{
            .mob_id = 1,
            .data_entity = game_data,
        });
        _ = ecs.set(world, player, components.mob.Position, .{
            .position = player_pos.pos,
        });
        _ = ecs.set(world, player, components.mob.Rotation, rotation);
        ecs.add(world, player, components.mob.NeedsSetup);
    }
    {
        // set up camera
        setThirdPersonCamera();
        var camera_rot: *components.screen.CameraRotation = ecs.get_mut(
            world,
            tpc,
            components.screen.CameraRotation,
        ) orelse std.debug.panic("expected camera rotation\n", .{});
        camera_rot.yaw = rotation.angle * -180;
        ecs.add(world, tpc, components.screen.Updated);
    }
    {
        // setup the bounding box
        const bounding_box = helpers.new_child(world, game_data);
        ecs.add_pair(
            world,
            player,
            mob_entities.HasBoundingBox,
            bounding_box,
        );
        _ = ecs.set(
            world,
            bounding_box,
            components.mob.BoundingBox,
            .{ .mob_id = 1, .mob_entity = player },
        );
        const c = math.vecs.Vflx4.initBytes(255, 255, 255, 255);
        _ = ecs.set(
            world,
            bounding_box,
            components.shape.Outline,
            .{ .color = c.value },
        );
        _ = ecs.set(
            world,
            bounding_box,
            components.shape.Color,
            .{ .color = .{ 0, 0, 0, 0 } },
        );
        ecs.add(world, bounding_box, components.mob.NeedsSetup);
    }
}

pub fn initBlockHighlight() void {
    const world = game.state.world;
    const bhl_e = helpers.new_child(world, game_data);
    _ = ecs.set(world, bhl_e, components.shape.Shape, .{ .shape_type = .block_highlight });
    const cr_c = math.vecs.Vflx4.initBytes(0, 0, 0, 0);
    _ = ecs.set(world, bhl_e, components.shape.Color, components.shape.Color.fromVec(cr_c));
    _ = ecs.set(world, bhl_e, components.shape.UBO, .{ .binding_point = gfx.constants.GameUBOBindingPoint });
    _ = ecs.set(game.state.world, bhl_e, components.screen.WorldLocation, .{
        .loc = @Vector(4, f32){ 30, 63, 30, 0 },
    });
    const c = math.vecs.Vflx4.initBytes(255, 255, 255, 255);
    _ = ecs.set(
        world,
        bhl_e,
        components.shape.Outline,
        .{ .color = c.value },
    );
    ecs.add(world, bhl_e, components.block.HighlightedBlock);
    ecs.add(world, bhl_e, components.shape.NeedsSetup);
    game.state.entities.block_highlight = bhl_e;
}

const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");
const config = @import("../../config.zig");
const components = @import("../components/components.zig");
const mob_entities = @import("entities_mob.zig");
const helpers = @import("../helpers.zig");
const gfx = @import("../../gfx/gfx.zig");
const data = @import("../../data/data.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
