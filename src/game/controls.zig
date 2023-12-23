const std = @import("std");
const zglfw = @import("zglfw");
const gl = @import("zopengl");
const zm = @import("zmath");
const state = @import("state.zig");

pub const Controls = struct {
    window: *zglfw.Window,
    appState: *state.State,

    pub fn init(window: *zglfw.Window, gameState: *state.State) !Controls {
        return Controls{
            .window = window,
            .appState = gameState,
        };
    }

    pub fn cursorPosCallback(self: *Controls, xpos: f64, ypos: f64) void {
        const x = @as(gl.Float, @floatCast(xpos));
        const y = @as(gl.Float, @floatCast(ypos));
        if (self.appState.game.firstMouse) {
            self.appState.game.lastX = x;
            self.appState.game.lastY = y;
            self.appState.game.firstMouse = false;
        }
        var xoffset = x - self.appState.game.lastX;
        var yoffset = self.appState.game.lastY - y;
        self.appState.game.lastX = x;
        self.appState.game.lastY = y;

        const sensitivity = 0.1;
        xoffset *= sensitivity;
        yoffset *= sensitivity;

        self.appState.game.yaw += xoffset;
        self.appState.game.pitch += yoffset;

        if (self.appState.game.pitch > 89.0) {
            self.appState.game.pitch = 89.0;
        }
        if (self.appState.game.pitch < -89.0) {
            self.appState.game.pitch = -89.0;
        }

        // pitch to radians
        const pitch = self.appState.game.pitch * (std.math.pi / 180.0);
        const yaw = self.appState.game.yaw * (std.math.pi / 180.0);
        const frontX = @cos(yaw) * @cos(pitch);
        const frontY = @sin(pitch);
        const frontZ = @sin(yaw) * @cos(pitch);
        const front: @Vector(4, gl.Float) = @Vector(4, gl.Float){ frontX, frontY, frontZ, 1.0 };

        if (self.appState.game.updateCameraFront(zm.normalize4(front))) {
            return;
        } else |err| {
            std.debug.print("Failed to update camera front: {}\n", .{err});
        }
    }

    pub fn handleKey(self: *Controls) !bool {
        if (self.window.getKey(.escape) == .press) {
            return true;
        }

        // wasd movement
        const cameraSpeed: @Vector(4, gl.Float) = @splat(2.5 * self.appState.game.deltaTime);
        if (self.window.getKey(.w) == .press) {
            const np = self.appState.game.cameraPos + self.appState.game.cameraFront * cameraSpeed;
            try self.appState.game.updateCameraPosition(np);
        }
        if (self.window.getKey(.s) == .press) {
            const np = self.appState.game.cameraPos - self.appState.game.cameraFront * cameraSpeed;
            try self.appState.game.updateCameraPosition(np);
        }
        if (self.window.getKey(.a) == .press) {
            const np = self.appState.game.cameraPos - zm.normalize3(zm.cross3(self.appState.game.cameraFront, self.appState.game.cameraUp)) * cameraSpeed;
            try self.appState.game.updateCameraPosition(np);
        }
        if (self.window.getKey(.d) == .press) {
            const np = self.appState.game.cameraPos + zm.normalize3(zm.cross3(self.appState.game.cameraFront, self.appState.game.cameraUp)) * cameraSpeed;
            try self.appState.game.updateCameraPosition(np);
        }

        if (self.window.getKey(.space) == .press) {
            const upDirection: @Vector(4, gl.Float) = @splat(1.0);
            const np = self.appState.game.cameraPos + self.appState.game.cameraUp * cameraSpeed * upDirection;
            try self.appState.game.updateCameraPosition(np);
        }
        if (self.window.getKey(.left_shift) == .press) {
            const downDirection: @Vector(4, gl.Float) = @splat(-1.0);
            const np = self.appState.game.cameraPos + self.appState.game.cameraUp * cameraSpeed * downDirection;
            try self.appState.game.updateCameraPosition(np);
        }

        return false;
    }
};
