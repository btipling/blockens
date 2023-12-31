const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl");
const state = @import("../state.zig");
const cube = @import("../shape/cube.zig");
const position = @import("../position.zig");
const texture_surface = @import("../shape/texture_surface.zig");

pub const TextureGenerator = struct {
    appState: *state.State,
    lookAt: zm.Mat,
    alloc: std.mem.Allocator,
    currentDemoCubeVersion: u32 = 0,
    displayCube: ?cube.Cube,
    top_surface: ?texture_surface.TextureSurface,
    side_surface: ?texture_surface.TextureSurface,
    bottom_surface: ?texture_surface.TextureSurface,

    pub fn init(appState: *state.State, alloc: std.mem.Allocator) !TextureGenerator {
        const cameraPos = @Vector(4, gl.Float){ 0.0, 0.0, 3.0, 1.0 };
        const cameraFront = @Vector(4, gl.Float){ 0.0, 0.0, -1.0, 0.0 };
        const cameraUp = @Vector(4, gl.Float){ 0.0, 1.0, 0.0, 0.0 };
        return TextureGenerator{
            .appState = appState,
            .displayCube = undefined,
            .top_surface = null,
            .side_surface = null,
            .bottom_surface = null,
            .lookAt = zm.lookAtRh(
                cameraPos,
                cameraPos + cameraFront,
                cameraUp,
            ),
            .alloc = alloc,
            .currentDemoCubeVersion = 0,
        };
    }

    fn setCube(self: *TextureGenerator) !void {
        const pos = position.Position{ .x = 0, .y = 0, .z = 0 };
        if (self.appState.app.demoTextureColors) |demoTextureColors| {
            const displayCube = try cube.Cube.initDemoCube("display_cube", cube.CubeType.demo, pos, self.alloc, &demoTextureColors);
            self.displayCube = displayCube;
            return;
        }
        self.displayCube = null;
    }

    fn setSurfaces(self: *TextureGenerator) !void {
        if (self.appState.app.demoTextureColors) |demoTextureColors| {
            var p = try texture_surface.TextureSurface.init(
                "top_surface",
                self.alloc,
                (&demoTextureColors)[0 .. 16 * 16],
            );
            self.top_surface = p;
            p = try texture_surface.TextureSurface.init(
                "side_surface",
                self.alloc,
                (&demoTextureColors)[16 * 16 .. 16 * 16 * 2],
            );
            self.side_surface = p;
            p = try texture_surface.TextureSurface.init(
                "bottom_surface",
                self.alloc,
                (&demoTextureColors)[16 * 16 * 2 .. 16 * 16 * 3],
            );
            self.bottom_surface = p;
        } else {
            self.top_surface = null;
            self.side_surface = null;
            self.bottom_surface = null;
        }
    }

    pub fn deinit(self: *TextureGenerator) void {
        if (self.displayCube) |displayCube| displayCube.deinit();
    }

    pub fn update(self: *TextureGenerator) !void {
        _ = self;
    }

    pub fn draw(self: *TextureGenerator) !void {
        try self.drawCube();
        try self.drawSurfaces();
    }

    pub fn drawSurfaces(self: *TextureGenerator) !void {
        if (self.top_surface) |p| {
            var mp = p;
            try mp.draw(zm.translation(-0.2925, 0.1, 0.0));
        }
        if (self.side_surface) |p| {
            var mp = p;
            try mp.draw(zm.translation(-0.2925, 0.021, 0.0));
        }
        if (self.bottom_surface) |p| {
            var mp = p;
            try mp.draw(zm.translation(-0.2925, -0.058, 0.0));
        }
    }

    pub fn drawCube(self: *TextureGenerator) !void {
        if (self.currentDemoCubeVersion != self.appState.app.demoCubeVersion) {
            try TextureGenerator.setCube(self);
            try TextureGenerator.setSurfaces(self);
            self.currentDemoCubeVersion = self.appState.app.demoCubeVersion;
        }
        if (self.displayCube) |displayCube| {
            var m = zm.identity();
            // rotate cube around its center
            m = zm.mul(m, zm.translationV(@Vector(4, gl.Float){ -0.5, -0.5, -0.5, 0.0 }));
            // scale to be small
            m = zm.mul(m, zm.scalingV(@Vector(4, gl.Float){ 0.33, 0.33, 0.33, 1.0 }));
            const zrot = zm.rotationZ(0.125 * std.math.pi * 2.0);
            m = zm.mul(m, zrot);
            const rotPerc: gl.Float = @as(gl.Float, @floatFromInt(@mod(std.time.milliTimestamp(), 10000))) / 10000.0;
            const yrot = zm.rotationY(rotPerc * std.math.pi * 2.0);
            m = zm.mul(m, yrot);
            m = zm.mul(m, self.lookAt);
            // translate to top left corner for a small view
            m = zm.mul(m, zm.translationV(@Vector(4, gl.Float){ -1.8, 1.2, 0.0, 0.0 }));
            try displayCube.draw(m);
        }
    }
};
