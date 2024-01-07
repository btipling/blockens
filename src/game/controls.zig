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
        if (self.appState.app.view != .game) {
            return;
        }
        const x = @as(gl.Float, @floatCast(xpos));
        const y = @as(gl.Float, @floatCast(ypos));
        if (self.appState.worldView.firstMouse) {
            self.appState.worldView.lastX = x;
            self.appState.worldView.lastY = y;
            self.appState.worldView.firstMouse = false;
        }
        var xoffset = x - self.appState.worldView.lastX;
        var yoffset = self.appState.worldView.lastY - y;
        self.appState.worldView.lastX = x;
        self.appState.worldView.lastY = y;

        const sensitivity = 0.1;
        xoffset *= sensitivity;
        yoffset *= sensitivity;

        self.appState.worldView.yaw += xoffset;
        self.appState.worldView.pitch += yoffset;

        if (self.appState.worldView.pitch > 89.0) {
            self.appState.worldView.pitch = 89.0;
        }
        if (self.appState.worldView.pitch < -89.0) {
            self.appState.worldView.pitch = -89.0;
        }

        // pitch to radians
        const pitch = self.appState.worldView.pitch * (std.math.pi / 180.0);
        const yaw = self.appState.worldView.yaw * (std.math.pi / 180.0);
        const frontX = @cos(yaw) * @cos(pitch);
        const frontY = @sin(pitch);
        const frontZ = @sin(yaw) * @cos(pitch);
        const front: @Vector(4, gl.Float) = @Vector(4, gl.Float){ frontX, frontY, frontZ, 1.0 };

        if (self.appState.worldView.updateCameraFront(zm.normalize4(front))) {
            return;
        } else |err| {
            std.debug.print("Failed to update camera front: {}\n", .{err});
        }
    }

    pub fn handleKey(self: *Controls) !bool {
        if (self.window.getKey(.escape) == .press) {
            return true;
        }

        if (self.window.getKey(.F2) == .press) {
            self.window.setInputMode(zglfw.InputMode.cursor, zglfw.Cursor.Mode.disabled);
            try self.appState.app.setGameView();
        }

        if (self.window.getKey(.F3) == .press) {
            self.window.setInputMode(zglfw.InputMode.cursor, zglfw.Cursor.Mode.normal);
            try self.appState.app.setTextureGeneratorView();
        }

        if (self.window.getKey(.F4) == .press) {
            self.window.setInputMode(zglfw.InputMode.cursor, zglfw.Cursor.Mode.normal);
            try self.appState.app.setWorldEditorView();
        }

        if (self.window.getKey(.F5) == .press) {
            self.window.setInputMode(zglfw.InputMode.cursor, zglfw.Cursor.Mode.normal);
            try self.appState.app.setBlockEditorView();
        }

        switch (self.appState.app.view) {
            .game => try self.handleGameKey(),
            .textureGenerator => try self.handleTextureGeneratorKey(),
            .worldEditor => try self.handleWorldEditorKey(),
            .blockEditor => try self.handleBlockEditorKey(),
        }

        return false;
    }

    fn handleGameKey(self: *Controls) !void {
        // wasd movement
        const cameraSpeed: @Vector(4, gl.Float) = @splat(2.5 * self.appState.worldView.deltaTime);
        if (self.window.getKey(.w) == .press) {
            const np = self.appState.worldView.cameraPos + self.appState.worldView.cameraFront * cameraSpeed;
            try self.appState.worldView.updateCameraPosition(np);
        }
        if (self.window.getKey(.s) == .press) {
            const np = self.appState.worldView.cameraPos - self.appState.worldView.cameraFront * cameraSpeed;
            try self.appState.worldView.updateCameraPosition(np);
        }
        if (self.window.getKey(.a) == .press) {
            const np = self.appState.worldView.cameraPos - zm.normalize3(zm.cross3(self.appState.worldView.cameraFront, self.appState.worldView.cameraUp)) * cameraSpeed;
            try self.appState.worldView.updateCameraPosition(np);
        }
        if (self.window.getKey(.d) == .press) {
            const np = self.appState.worldView.cameraPos + zm.normalize3(zm.cross3(self.appState.worldView.cameraFront, self.appState.worldView.cameraUp)) * cameraSpeed;
            try self.appState.worldView.updateCameraPosition(np);
        }

        if (self.window.getKey(.space) == .press) {
            const upDirection: @Vector(4, gl.Float) = @splat(1.0);
            const np = self.appState.worldView.cameraPos + self.appState.worldView.cameraUp * cameraSpeed * upDirection;
            try self.appState.worldView.updateCameraPosition(np);
        }
        if (self.window.getKey(.left_shift) == .press) {
            const downDirection: @Vector(4, gl.Float) = @splat(-1.0);
            const np = self.appState.worldView.cameraPos + self.appState.worldView.cameraUp * cameraSpeed * downDirection;
            try self.appState.worldView.updateCameraPosition(np);
        }
    }

    fn handleTextureGeneratorKey(_: *Controls) !void {}
    fn handleWorldEditorKey(_: *Controls) !void {}
    fn handleBlockEditorKey(_: *Controls) !void {}
};
