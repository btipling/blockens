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
    alloc: std.mem.Allocator,
    currentDemoCubeVersion: u32 = 0,

    pub fn init(appState: *state.State, alloc: std.mem.Allocator) !TextureGenerator {
        const cameraPos = @Vector(4, gl.Float){ 0.0, 0.0, 3.0, 1.0 };
        const cameraFront = @Vector(4, gl.Float){ 0.0, 0.0, -1.0, 0.0 };
        const cameraUp = @Vector(4, gl.Float){ 0.0, 1.0, 0.0, 0.0 };
        var tg = TextureGenerator{
            .appState = appState,
            .displayCube = undefined,
            .lookAt = zm.lookAtRh(
                cameraPos,
                cameraPos + cameraFront,
                cameraUp,
            ),
            .alloc = alloc,
            .currentDemoCubeVersion = 0,
        };
        try TextureGenerator.setCube(&tg);
        return tg;
    }

    fn setCube(self: *TextureGenerator) !void {
        const pos = position.Position{ .x = 0, .y = 0, .z = 0 };
        if (self.appState.app.demoTextureColors) |demoTextureColors| {
            const displayCube = try cube.Cube.initDemoCube("display_cube", cube.CubeType.demo, pos, self.alloc, demoTextureColors);
            self.displayCube = displayCube;
            return;
        }
        const displayCube = try cube.Cube.init("display_cube", cube.CubeType.grass, pos, self.alloc);
        self.displayCube = displayCube;
    }

    pub fn deinit(self: *TextureGenerator) void {
        self.displayCube.deinit();
    }

    pub fn update(self: *TextureGenerator) !void {
        _ = self;
    }

    pub fn draw(self: *TextureGenerator) !void {
        if (self.currentDemoCubeVersion != self.appState.app.demoCubeVersion) {
            try TextureGenerator.setCube(self);
            self.currentDemoCubeVersion = self.appState.app.demoCubeVersion;
        }
        var m = zm.identity();
        // rotate cube around its center
        m = zm.mul(m, zm.translationV(@Vector(4, gl.Float){ -0.5, -0.5, -0.5, 0.0 }));
        const zrot = zm.rotationZ(0.125 * std.math.pi * 2.0);
        m = zm.mul(m, zrot);
        const rotPerc: gl.Float = @as(gl.Float, @floatFromInt(@mod(std.time.milliTimestamp(), 10000))) / 10000.0;
        const yrot = zm.rotationY(rotPerc * std.math.pi * 2.0);
        m = zm.mul(m, yrot);
        // translate to top left corner for a small view
        m = zm.mul(m, zm.translationV(@Vector(4, gl.Float){ -5.0, 3.5, 0.0, 0.0 }));
        // scale to be small
        m = zm.mul(m, zm.scalingV(@Vector(4, gl.Float){ 0.33, 0.33, 0.33, 1.0 }));
        m = zm.mul(m, self.lookAt);
        try self.displayCube.draw(m);
    }
};
