pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "SettingsHotkeysSystem", ecs.OnLoad, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.Settings) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    const screen: *const components.screen.Screen = ecs.get(
        world,
        game.state.entities.screen,
        components.screen.Screen,
    ) orelse return;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            if (ecs.has_id(world, screen.current, ecs.id(components.screen.ChunkEditor))) {
                handleChunkHotKeys();
            }
            if (ecs.has_id(world, screen.current, ecs.id(components.screen.CharacterEditor))) {
                handleCharacterHotKeys();
            }
        }
    }
}

// Y first because roll (y), pitch , yaw
const rotation_axis = enum { y, x, z };
const direction = enum { positive, negative };

const rotation_velocity: f32 = 90.0 * (std.math.pi / 180.0);

fn rotateScreen(world: *ecs.world_t, axis: rotation_axis, dir: direction) void {
    const screen = game.state.entities.screen;
    if (ecs.has_id(world, screen, ecs.id(components.screen.WorldRotating))) return;

    var rot_y = game.state.ui.demo_screen_rotation_y;
    var rot_x = game.state.ui.demo_screen_rotation_x;
    var rot_z = game.state.ui.demo_screen_rotation_z;

    // In order to slerp rotation between frames two quaternions are created from the current euler angles in state.
    const start_rotation = zm.quatFromRollPitchYaw(rot_y, rot_z, rot_x);

    const change = rotation_velocity * if (dir == .positive) @as(f32, 1) else @as(f32, -1);
    switch (axis) {
        .y => rot_y += change,
        .x => rot_x += change,
        .z => rot_z += change,
    }

    const end_rotation = zm.quatFromRollPitchYaw(rot_y, rot_z, rot_x);

    _ = ecs.set(world, screen, components.screen.WorldRotating, .{
        .start_rotation = start_rotation,
        .end_rotation = end_rotation,
        .started_at = game.state.input.lastframe,
    });
}

fn handleChunkHotKeys() void {
    const world = game.state.world;
    if (input.keys.holdKey(.left)) rotateScreen(world, .z, .positive);
    if (input.keys.holdKey(.right)) rotateScreen(world, .z, .negative);
}

// FIXME: These WorldTranslation modifications are FPS bound and shouldn't be.
fn handleCharacterHotKeys() void {
    const world = game.state.world;
    const char_speed: f32 = 0.024;
    if (input.keys.holdKey(.left)) {
        if (input.keys.holdKey(.left_shift)) {
            var w_tr: *components.screen.WorldTranslation = ecs.get_mut(
                world,
                game.state.entities.settings_camera,
                components.screen.WorldTranslation,
            ) orelse return;
            w_tr.translation[0] += char_speed; // Manipulating these values directly here is not correct.
        } else rotateScreen(world, .z, .positive);
    }
    if (input.keys.holdKey(.right)) {
        if (input.keys.holdKey(.left_shift)) {
            var w_tr: *components.screen.WorldTranslation = ecs.get_mut(
                world,
                game.state.entities.settings_camera,
                components.screen.WorldTranslation,
            ) orelse return;
            w_tr.translation[0] -= char_speed;
        } else rotateScreen(world, .z, .negative);
    }
    if (input.keys.holdKey(.up)) {
        if (input.keys.holdKey(.left_shift)) {
            var w_tr: *components.screen.WorldTranslation = ecs.get_mut(
                world,
                game.state.entities.settings_camera,
                components.screen.WorldTranslation,
            ) orelse return;
            w_tr.translation[1] += char_speed;
        } else rotateScreen(world, .x, .positive);
    }
    if (input.keys.holdKey(.down)) {
        if (input.keys.holdKey(.left_shift)) {
            var w_tr: *components.screen.WorldTranslation = ecs.get_mut(
                world,
                game.state.entities.settings_camera,
                components.screen.WorldTranslation,
            ) orelse return;
            w_tr.translation[1] -= char_speed;
        } else rotateScreen(world, .x, .negative);
    }
}

const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const components = @import("../../../components/components.zig");
const entities = @import("../../../entities/entities.zig");
const game = @import("../../../../game.zig");
const input = @import("../../../../input/input.zig");
