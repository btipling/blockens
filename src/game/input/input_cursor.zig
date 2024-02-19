const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const game = @import("../game.zig");
const blecs = @import("../blecs/blecs.zig");
const zgui = @import("zgui");
const gameState = @import("../state/game.zig");

pub fn cursorPosCallback(xpos: f64, ypos: f64) void {
    const x: gl.Float = @floatCast(xpos);
    const y: gl.Float = @floatCast(ypos);
    var last_x: gl.Float = x;
    var last_y: gl.Float = y;
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

    var camera_rot: *blecs.components.screen.CameraRotation = blecs.ecs.get_mut(
        game.state.world,
        game.state.entities.game_camera,
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
    const front: @Vector(4, gl.Float) = @Vector(4, gl.Float){ frontX, frontY, frontZ, 1.0 };

    game.state.input.cursor.?.last_x = x;
    game.state.input.cursor.?.last_y = y;
    const imguiWantsMouse = zgui.io.getWantCaptureMouse();
    const menu: *const blecs.components.ui.Menu = blecs.ecs.get(
        game.state.world,
        game.state.entities.menu,
        blecs.components.ui.Menu,
    ) orelse unreachable;
    if (imguiWantsMouse or menu.visible) {
        return;
    }

    var camera_front: *blecs.components.screen.CameraFront = blecs.ecs.get_mut(
        game.state.world,
        game.state.entities.game_camera,
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
        game.state.entities.game_camera,
        blecs.components.screen.Updated,
    );
}
