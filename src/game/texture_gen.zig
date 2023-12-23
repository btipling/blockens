const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl");
const state = @import("state.zig");
const cube = @import("cube.zig");
const position = @import("position.zig");

pub const TextureGenerator = struct {
    appState: *state.State,
    displayCube: cube.Cube,
    lookAt: zm.Mat,

    pub fn init(appState: *state.State, alloc: std.mem.Allocator) !TextureGenerator {
        const pos = position.Position{ .x = 0, .y = 0, .z = -0.5 };
        const displayCube = try cube.Cube.init("display_cube", cube.CubeType.grass, pos, alloc);

        const cameraPos = @Vector(4, gl.Float){ 0.0, 1.0, 3.0, 1.0 };
        const cameraFront = @Vector(4, gl.Float){ 0.0, 0.0, -1.0, 0.0 };
        const cameraUp = @Vector(4, gl.Float){ 0.0, 1.0, 0.0, 0.0 };
        return TextureGenerator{
            .appState = appState,
            .displayCube = displayCube,
            .lookAt = zm.lookAtRh(
                cameraPos,
                cameraPos + cameraFront,
                cameraUp,
            ),
        };
    }

    pub fn deinit(self: *TextureGenerator) void {
        self.displayCube.deinit();
    }

    pub fn update(self: *TextureGenerator) !void {
        _ = self;
    }

    pub fn draw(self: *TextureGenerator) !void {
        try self.displayCube.draw(self.lookAt);
    }
};
