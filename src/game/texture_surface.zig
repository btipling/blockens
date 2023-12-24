const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const shape = @import("shape.zig");

pub const TextureSurface = struct {
    name: []const u8,
    shape: shape.Shape,

    pub fn init(
        name: []const u8,
        alloc: std.mem.Allocator,
        textureRGBAColors: []const gl.Uint,
    ) !TextureSurface {
        var plane = zmesh.Shape.initPlane(1, 1);
        plane.translate(-0.5, -0.5, 0.0);
        plane.rotate(std.math.pi * 1.0, 0.0, 0.0, 1.0);
        plane.scale(0.075, 0.075, 1.0);
        defer plane.deinit();

        const vertexShaderSource = @embedFile("shaders/demo_surface.vs");
        const fragmentShaderSource = @embedFile("shaders/demo_surface.fs");

        const s = try shape.Shape.init(
            name,
            plane,
            vertexShaderSource,
            fragmentShaderSource,
            null,
            null,
            textureRGBAColors,
            shape.ShapeConfig{ .textureType = shape.textureDataType.RGBAColor, .isCube = false, .hasPerspective = false },
            alloc,
        );
        return TextureSurface{
            .name = name,
            .shape = s,
        };
    }

    pub fn deinit(self: *TextureSurface) void {
        self.shape.deinit();
    }

    pub fn draw(self: *TextureSurface, givenM: zm.Mat) !void {
        var m = zm.identity();
        m = zm.mul(m, zm.translation(-0.01, 0.0, -0.5));
        try self.shape.draw(zm.mul(m, givenM));
    }
};
