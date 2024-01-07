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
        var viewState = self.appState.worldView;
        const x = @as(gl.Float, @floatCast(xpos));
        const y = @as(gl.Float, @floatCast(ypos));
        if (viewState.firstMouse) {
            viewState.lastX = x;
            viewState.lastY = y;
        }
        var xoffset = x - viewState.lastX;
        var yoffset = viewState.lastY - y;

        const sensitivity = 0.1;
        xoffset *= sensitivity;
        yoffset *= sensitivity;

        viewState.yaw += xoffset;
        viewState.pitch += yoffset;

        if (viewState.pitch > 89.0) {
            viewState.pitch = 89.0;
        }
        if (viewState.pitch < -89.0) {
            viewState.pitch = -89.0;
        }

        // pitch to radians
        const pitch = viewState.pitch * (std.math.pi / 180.0);
        const yaw = viewState.yaw * (std.math.pi / 180.0);
        const frontX = @cos(yaw) * @cos(pitch);
        const frontY = @sin(pitch);
        const frontZ = @sin(yaw) * @cos(pitch);
        const front: @Vector(4, gl.Float) = @Vector(4, gl.Float){ frontX, frontY, frontZ, 1.0 };

        if (self.appState.worldView.updateCameraFront(viewState.pitch, viewState.yaw, x, y, zm.normalize4(front))) {
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

        if (self.window.getKey(.F6) == .press) {
            self.window.setInputMode(zglfw.InputMode.cursor, zglfw.Cursor.Mode.normal);
            try self.appState.app.setClusterGeneratorView();
        }

        switch (self.appState.app.view) {
            .game => try self.handleGameKey(),
            .textureGenerator => try self.handleTextureGeneratorKey(),
            .worldEditor => try self.handleWorldEditorKey(),
            .blockEditor => try self.handleBlockEditorKey(),
            .clusterGenerator => try self.handleClusterGeneratorKey(),
        }

        return false;
    }

    fn handleGameKey(self: *Controls) !void {
        // wasd movement
        const viewState = self.appState.worldView;
        var speed = 2.5 * viewState.deltaTime;
        if (self.window.getKey(.left_control) != .press) {
            speed *= 20.0;
        }
        const cameraSpeed: @Vector(4, gl.Float) = @splat(speed);
        if (self.window.getKey(.w) == .press) {
            const np = viewState.cameraPos + viewState.cameraFront * cameraSpeed;
            try self.appState.worldView.updateCameraPosition(np);
        }
        if (self.window.getKey(.s) == .press) {
            const np = viewState.cameraPos - viewState.cameraFront * cameraSpeed;
            try self.appState.worldView.updateCameraPosition(np);
        }
        if (self.window.getKey(.a) == .press) {
            const np = viewState.cameraPos - zm.normalize3(zm.cross3(viewState.cameraFront, viewState.cameraUp)) * cameraSpeed;
            try self.appState.worldView.updateCameraPosition(np);
        }
        if (self.window.getKey(.d) == .press) {
            const np = viewState.cameraPos + zm.normalize3(zm.cross3(viewState.cameraFront, viewState.cameraUp)) * cameraSpeed;
            try self.appState.worldView.updateCameraPosition(np);
        }

        if (self.window.getKey(.space) == .press) {
            const upDirection: @Vector(4, gl.Float) = @splat(1.0);
            const np = viewState.cameraPos + viewState.cameraUp * cameraSpeed * upDirection;
            try self.appState.worldView.updateCameraPosition(np);
        }
        if (self.window.getKey(.left_shift) == .press) {
            const downDirection: @Vector(4, gl.Float) = @splat(-1.0);
            const np = viewState.cameraPos + viewState.cameraUp * cameraSpeed * downDirection;
            try self.appState.worldView.updateCameraPosition(np);
        }
        if (self.window.getKey(.r) == .press) {
            try self.appState.worldView.rotateWorld();
        }
        if (self.window.getKey(.t) == .press) {
            try self.appState.worldView.rotateWorldInReverse();
        }
    }

    fn handleTextureGeneratorKey(_: *Controls) !void {}
    fn handleWorldEditorKey(_: *Controls) !void {}
    fn handleBlockEditorKey(_: *Controls) !void {}
    fn handleClusterGeneratorKey(_: *Controls) !void {}
};
