const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const shape = @import("shape.zig");
const position = @import("position.zig");

const Vtx = struct {
    indices: []gl.Uint,
    position: [3]gl.Float,
};

pub const Cube = struct {
    name: []const u8,
    position: position.Position,
    shape: shape.Shape,

    pub fn init(name: []const u8, pos: position.Position, alloc: std.mem.Allocator) !Cube {
        var cube = zmesh.Shape.initCube();
        defer cube.deinit();

        cube.rotate(std.math.pi * 0.5, 0.0, 0.0, 1.0);

        const vertexShaderSource = @embedFile("shaders/cube.vs");
        const fragmentShaderSource = @embedFile("shaders/cube.fs");
        const textureSource = @embedFile("assets/textures/smilie.png");

        const s = try shape.Shape.init(
            name,
            cube,
            vertexShaderSource,
            fragmentShaderSource,
            textureSource,
            shape.ShapeConfig{ .hasColor = false, .hasTexture = true },
            alloc,
        );
        return Cube{
            .name = name,
            .position = pos,
            .shape = s,
        };
    }

    pub fn deinit(self: *Cube) void {
        self.shape.deinit();
    }

    pub fn draw(self: *Cube, givenM: zm.Mat) !void {
        var m = zm.mul(zm.translation(0.5, 0.5, -0.5), givenM);
        var angleDegrees: gl.Float = 20.0 * (std.math.pi / 180.0);
        // m = zm.mul(zm.rotationZ(angleDegrees), m);
        angleDegrees = 80.0 * (std.math.pi / 180.0);
        m = zm.mul(zm.rotationX(angleDegrees), m);
        // angleDegrees = 140.0 * (std.math.pi / 180.0);
        // m = zm.mul(zm.rotationY(angleDegrees), m);
        // m = zm.mul(zm.scaling(0.5, 0.5, 0.5), m);
        try self.shape.draw(m);
    }
};
