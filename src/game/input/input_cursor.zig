const std = @import("std");
const zm = @import("zmath");
const game = @import("../game.zig");
const blecs = @import("../blecs/blecs.zig");
const zgui = @import("zgui");
const gameState = @import("../state/state.zig");

pub fn cursorPosCallback(xpos: f64, ypos: f64) void {
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

    var x_offset = x - last_x;
    var y_offset = last_y - y;

    const sensitivity = 0.1;
    x_offset *= sensitivity;
    y_offset *= sensitivity;

    const screen: *const blecs.components.screen.Screen = blecs.ecs.get(
        game.state.world,
        game.state.entities.screen,
        blecs.components.screen.Screen,
    ) orelse unreachable;

    var camera = game.state.entities.sky_camera;
    if (blecs.ecs.has_id(game.state.world, screen.current, blecs.ecs.id(blecs.components.screen.Settings))) {
        camera = game.state.entities.settings_camera;
    }

    var camera_rot: *blecs.components.screen.CameraRotation = blecs.ecs.get_mut(
        game.state.world,
        camera,
        blecs.components.screen.CameraRotation,
    ) orelse return;
    const camera_rot_yaw = camera_rot.yaw + x_offset;
    var camera_rot_pitch = camera_rot.pitch + y_offset;

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
        game.state.world,
        game.state.entities.ui,
        blecs.ecs.id(blecs.components.ui.Menu),
    );
    if (imguiWantsMouse or menu_visible) {
        return;
    }

    var camera_front: *blecs.components.screen.CameraFront = blecs.ecs.get_mut(
        game.state.world,
        camera,
        blecs.components.screen.CameraFront,
    ) orelse {
        std.debug.print("no camera front yet\n", .{});
        return;
    };
    camera_front.front = zm.normalize4(front);
    camera_rot.pitch = camera_rot_pitch;
    camera_rot.yaw = camera_rot_yaw;
    blecs.ecs.add(
        game.state.world,
        camera,
        blecs.components.screen.Updated,
    );
}
