const std = @import("std");
const zglfw = @import("zglfw");
const gl = @import("zopengl").bindings;
const zgui = @import("zgui");
const zm = @import("zmath");
const state = @import("./state/state.zig");

pub const Controls = struct {
    window: *zglfw.Window,
    appState: *state.State,
    controlsLastUpdated: i64,

    pub fn init(window: *zglfw.Window, gameState: *state.State) !Controls {
        return Controls{
            .window = window,
            .appState = gameState,
            .controlsLastUpdated = 0,
        };
    }

    pub fn cursorPosCallback(self: *Controls, xpos: f64, ypos: f64) void {
        var viewState = self.appState.worldScreen;
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

        const imguiWantsMouse = zgui.io.getWantCaptureMouse();
        if (imguiWantsMouse or self.appState.app.currentScreen != .game) {
            // This keeps the camera from jerking around after having used the mouse in non-game view
            self.appState.worldScreen.updateCameraState(x, y);
            return;
        }
        if (self.appState.worldScreen.updateCameraFront(viewState.pitch, viewState.yaw, x, y, zm.normalize4(front))) {
            return;
        } else |err| {
            std.debug.print("Failed to update camera front: {}\n", .{err});
        }
    }

    pub fn handleKey(self: *Controls) !bool {
        const imguiWantsKey = zgui.io.getWantCaptureKeyboard();
        if (imguiWantsKey) {
            return false;
        }

        if (self.window.getKey(.escape) == .press and self.window.getKey(.left_shift) == .press) {
            return true;
        }

        if (self.window.getKey(.F1) == .press) {
            self.window.setInputMode(zglfw.InputMode.cursor, zglfw.Cursor.Mode.normal);
            try self.appState.setTextureGeneratorScreen();
        }

        if (self.window.getKey(.F2) == .press) {
            self.window.setInputMode(zglfw.InputMode.cursor, zglfw.Cursor.Mode.disabled);
            try self.appState.setGameScreen();
        }

        switch (self.appState.app.currentScreen) {
            .game => try self.handleGameKey(),
            .textureGenerator => try self.handleTextureGeneratorKey(),
            .worldEditor => try self.handleWorldEditorKey(),
            .blockEditor => try self.handleBlockEditorKey(),
            .chunkGenerator => try self.handleChunkGeneratorKey(),
            .characterDesigner => try self.handleCharacterDesignerKey(),
            .paused => {},
        }

        return false;
    }

    fn handleGameKey(self: *Controls) !void {
        // wasd movement
        const viewState = self.appState.worldScreen;
        var speed = 2.5 * viewState.deltaTime;
        if (self.window.getKey(.left_control) != .press) {
            speed *= 20.0;
        }
        const cameraSpeed: @Vector(4, gl.Float) = @splat(speed);
        self.appState.character.disableWalking();
        if (self.window.getKey(.w) == .press) {
            self.appState.character.enableWalking();
            const np = viewState.cameraPos + viewState.cameraFront * cameraSpeed;
            try self.appState.worldScreen.updateCameraPosition(np);
        }
        if (self.window.getKey(.s) == .press) {
            self.appState.character.enableWalking();
            const np = viewState.cameraPos - viewState.cameraFront * cameraSpeed;
            try self.appState.worldScreen.updateCameraPosition(np);
        }
        if (self.window.getKey(.a) == .press) {
            self.appState.character.enableWalking();
            const np = viewState.cameraPos - zm.normalize3(zm.cross3(viewState.cameraFront, viewState.cameraUp)) * cameraSpeed;
            try self.appState.worldScreen.updateCameraPosition(np);
        }
        if (self.window.getKey(.d) == .press) {
            self.appState.character.enableWalking();
            const np = viewState.cameraPos + zm.normalize3(zm.cross3(viewState.cameraFront, viewState.cameraUp)) * cameraSpeed;
            try self.appState.worldScreen.updateCameraPosition(np);
        }

        if (self.window.getKey(.space) == .press) {
            const upDirection: @Vector(4, gl.Float) = @splat(1.0);
            const np = viewState.cameraPos + viewState.cameraUp * cameraSpeed * upDirection;
            try self.appState.worldScreen.updateCameraPosition(np);
        }
        if (self.window.getKey(.left_shift) == .press) {
            const downDirection: @Vector(4, gl.Float) = @splat(-1.0);
            const np = viewState.cameraPos + viewState.cameraUp * cameraSpeed * downDirection;
            try self.appState.worldScreen.updateCameraPosition(np);
        }
        if (self.window.getKey(.F3) == .press) {
            const now = std.time.milliTimestamp();
            if (now - self.controlsLastUpdated >= 250) {
                self.controlsLastUpdated = now;
                self.appState.worldScreen.toggleWireframe();
            }
        }
    }

    fn uiControls(self: *Controls) !void {
        if (self.window.getKey(.F11) == .press) {
            const now = std.time.milliTimestamp();
            if (now - self.controlsLastUpdated >= 250) {
                self.controlsLastUpdated = now;
                self.appState.demoScreen.toggleUIMetrics();
            }
        }
        if (self.window.getKey(.F12) == .press) {
            const now = std.time.milliTimestamp();
            if (now - self.controlsLastUpdated >= 250) {
                self.controlsLastUpdated = now;
                self.appState.demoScreen.toggleUILog();
            }
        }
    }

    fn handleTextureGeneratorKey(self: *Controls) !void {
        try self.uiControls();
    }

    fn handleWorldEditorKey(self: *Controls) !void {
        try self.uiControls();
    }

    fn handleBlockEditorKey(self: *Controls) !void {
        try self.uiControls();
    }

    fn handleChunkGeneratorKey(self: *Controls) !void {
        if (self.window.getKey(.right) == .press) {
            try self.appState.demoScreen.rotateWorld();
        }
        if (self.window.getKey(.left) == .press) {
            try self.appState.demoScreen.rotateWorldInReverse();
        }
        if (self.window.getKey(.up) == .press) {
            const now = std.time.milliTimestamp();
            if (now - self.controlsLastUpdated >= 250) {
                self.controlsLastUpdated = now;
                try self.appState.app.toggleChunkGeneratorUI();
                try self.appState.demoScreen.toggleScreenTransform();
            }
        }
        if (self.window.getKey(.F3) == .press) {
            const now = std.time.milliTimestamp();
            if (now - self.controlsLastUpdated >= 250) {
                self.controlsLastUpdated = now;
                self.appState.demoScreen.toggleWireframe();
            }
        }
        try self.uiControls();
    }

    fn handleCharacterDesignerKey(self: *Controls) !void {
        const amount: gl.Float = 0.002;
        if (self.window.getKey(.a) == .press) {
            try self.appState.character.rotateZ(amount);
        }
        if (self.window.getKey(.s) == .press) {
            try self.appState.character.rotateZ(amount * -1);
        }
        if (self.window.getKey(.up) == .press) {
            try self.appState.character.rotateX(amount);
        }
        if (self.window.getKey(.down) == .press) {
            try self.appState.character.rotateX(amount * -1);
        }
        if (self.window.getKey(.left) == .press) {
            try self.appState.character.rotateY(amount);
        }
        if (self.window.getKey(.right) == .press) {
            try self.appState.character.rotateY(amount * -1);
        }
        try self.uiControls();
    }
};
