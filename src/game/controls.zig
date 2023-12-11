const std = @import("std");
const zglfw = @import("zglfw");
const gl = @import("zopengl");
const zm = @import("zmath");
const state = @import("state.zig");

pub const Controls = struct {
    window: *zglfw.Window,
    gameState: *state.State,

    pub fn init(window: *zglfw.Window, gameState: *state.State) !Controls {
        return Controls{
            .window = window,
            .gameState = gameState,
        };
    }

    pub fn cursorPosCallback(self: *Controls, xpos: f64, ypos: f64) void {
        const x = @as(gl.Float, @floatCast(xpos));
        const y = @as(gl.Float, @floatCast(ypos));
        if (self.gameState.firstMouse) {
            self.gameState.lastX = x;
            self.gameState.lastY = y;
            self.gameState.firstMouse = false;
        }
        var xoffset = x - self.gameState.lastX;
        var yoffset = self.gameState.lastY - y;
        self.gameState.lastX = x;
        self.gameState.lastY = y;

        const sensitivity = 0.1;
        xoffset *= sensitivity;
        yoffset *= sensitivity;

        self.gameState.yaw += xoffset;
        self.gameState.pitch += yoffset;

        if (self.gameState.pitch > 89.0) {
            self.gameState.pitch = 89.0;
        }
        if (self.gameState.pitch < -89.0) {
            self.gameState.pitch = -89.0;
        }

        // pitch to radians
        const pitch = self.gameState.pitch * (std.math.pi / 180.0);
        const yaw = self.gameState.yaw * (std.math.pi / 180.0);
        const frontX = @cos(yaw) * @cos(pitch);
        const frontY = @sin(pitch);
        const frontZ = @sin(yaw) * @cos(pitch);
        const front: @Vector(4, gl.Float) = @Vector(4, gl.Float){ frontX, frontY, frontZ, 1.0 };

        self.gameState.cameraFront = zm.normalize4(front);
    }

    pub fn handleKey(self: *Controls) !bool {
        if (self.window.getKey(.escape) == .press) {
            return true;
        }

        // wasd movement
        const cameraSpeed: @Vector(4, gl.Float) = @splat(2.5 * self.gameState.deltaTime);
        if (self.window.getKey(.w) == .press) {
            self.gameState.cameraPos += self.gameState.cameraFront * cameraSpeed;
        }
        if (self.window.getKey(.s) == .press) {
            self.gameState.cameraPos -= self.gameState.cameraFront * cameraSpeed;
        }
        if (self.window.getKey(.a) == .press) {
            self.gameState.cameraPos -= zm.normalize3(zm.cross3(self.gameState.cameraFront, self.gameState.cameraUp)) * cameraSpeed;
        }
        if (self.window.getKey(.d) == .press) {
            self.gameState.cameraPos += zm.normalize3(zm.cross3(self.gameState.cameraFront, self.gameState.cameraUp)) * cameraSpeed;
        }

        if (self.window.getKey(.space) == .press) {
            const upDirection: @Vector(4, gl.Float) = @splat(1.0);
            self.gameState.cameraPos += self.gameState.cameraUp * cameraSpeed * upDirection;
        }
        if (self.window.getKey(.left_shift) == .press) {
            const downDirection: @Vector(4, gl.Float) = @splat(-1.0);
            self.gameState.cameraPos += self.gameState.cameraUp * cameraSpeed * downDirection;
        }

        return false;
    }
};
