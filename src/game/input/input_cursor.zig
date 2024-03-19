const std = @import("std");
const zm = @import("zmath");
const game = @import("../game.zig");
const blecs = @import("../blecs/blecs.zig");
const zgui = @import("zgui");
const gameState = @import("../state.zig");

pub fn cursorPosCallback(xpos: f64, ypos: f64) void {
    const world = game.state.world;
    const x: f32 = @floatCast(xpos);
    const y: f32 = @floatCast(ypos);
    var last_x: f32 = x;
    var last_y: f32 = y;
    var needsUpdate = false;
    if (game.state.input.cursor) |c| {
        if (c.last_x != x or c.last_y != y) needsUpdate = true;
        last_x = c.last_x;
        last_y = c.last_y;
    } else {
        game.state.input.cursor = gameState.Cursor{ .last_x = x, .last_y = y };
        needsUpdate = true;
    }
    if (!needsUpdate) return;

    const screen: *const blecs.components.screen.Screen = blecs.ecs.get(
        world,
        game.state.entities.screen,
        blecs.components.screen.Screen,
    ) orelse unreachable;

    var is_game_camera = false;
    var camera = game.state.entities.settings_camera;
    if (!blecs.ecs.has_id(world, screen.current, blecs.ecs.id(blecs.components.screen.Settings))) {
        var filter_desc: blecs.ecs.filter_desc_t = .{};
        filter_desc.terms[0] = .{ .id = blecs.ecs.id(blecs.components.screen.CurrentCamera) };
        const filter = blecs.ecs.filter_init(world, &filter_desc) catch unreachable;
        var it = blecs.ecs.filter_iter(world, filter);
        while (blecs.ecs.filter_next(&it)) {
            camera = it.entities()[0];
            is_game_camera = true;
            break;
        }
        blecs.ecs.iter_fini(&it);
        blecs.ecs.filter_fini(filter);
    }

    var x_offset: f32 = x - last_x;
    var y_offset: f32 = last_y - y;

    const sensitivity: f32 = 0.1;
    x_offset *= sensitivity;
    y_offset *= sensitivity;

    var camera_rot: *blecs.components.screen.CameraRotation = blecs.ecs.get_mut(
        world,
        camera,
        blecs.components.screen.CameraRotation,
    ) orelse return;
    const camera_rot_yaw: f32 = camera_rot.yaw + x_offset;
    var camera_rot_pitch: f32 = camera_rot.pitch + y_offset;

    if (camera_rot_pitch > 89.0) {
        camera_rot_pitch = 89.0;
    }
    if (camera_rot_pitch < -89.0) {
        camera_rot_pitch = -89.0;
    }

    // pitch to radians
    const pitch = camera_rot_pitch * (std.math.pi / 180.0);
    const yaw = camera_rot_yaw * (std.math.pi / 180.0);
    const frontX = @cos(yaw) * @cos(pitch);
    const frontY = @sin(pitch);
    const frontZ = @sin(yaw) * @cos(pitch);
    const front: @Vector(4, f32) = @Vector(4, f32){ frontX, frontY, frontZ, 1.0 };

    game.state.input.cursor.?.last_x = x;
    game.state.input.cursor.?.last_y = y;
    const imguiWantsMouse = zgui.io.getWantCaptureMouse();
    const menu_visible = blecs.ecs.has_id(
        world,
        game.state.entities.ui,
        blecs.ecs.id(blecs.components.ui.Menu),
    );
    const ui: ?*const blecs.components.ui.UI = blecs.ecs.get(
        world,
        game.state.entities.ui,
        blecs.components.ui.UI,
    );
    var dialog_visible = false;
    if (ui) |_ui| dialog_visible = _ui.dialog_count > 0;
    if (imguiWantsMouse or menu_visible or dialog_visible) {
        return;
    }

    var camera_front: *blecs.components.screen.CameraFront = blecs.ecs.get_mut(
        world,
        camera,
        blecs.components.screen.CameraFront,
    ) orelse {
        std.debug.print("no camera front yet\n", .{});
        return;
    };
    if (is_game_camera and camera != game.state.entities.sky_camera) {
        const rotation: *blecs.components.mob.Rotation = blecs.ecs.get_mut(
            game.state.world,
            game.state.entities.player,
            blecs.components.mob.Rotation,
        ) orelse return;
        const rot = rotation.rotation;
        const angle: f32 = -camera_rot_yaw / 180;
        const up = @Vector(4, f32){ 0.0, 1.0, 0.0, 0.0 };
        const turn = zm.quatFromNormAxisAngle(up, angle);
        const new_rot: @Vector(4, f32) = zm.rotate(rot, turn);
        rotation.rotation = new_rot;
        rotation.angle = angle;
        blecs.ecs.add(game.state.world, game.state.entities.player, blecs.components.mob.NeedsUpdate);
    }
    camera_front.front = zm.normalize4(front);
    camera_rot.pitch = camera_rot_pitch;
    camera_rot.yaw = camera_rot_yaw;
    blecs.ecs.add(
        world,
        camera,
        blecs.components.screen.Updated,
    );
}
