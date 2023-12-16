const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const shape = @import("shape.zig");
const position = @import("position.zig");

pub const Cube = struct {
    name: []const u8,
    position: position.Position,
    shape: shape.Shape,

    pub fn init(name: []const u8, pos: position.Position, alloc: std.mem.Allocator) !Cube {
        // var cube = zmesh.Shape.initCube();
        // defer cube.deinit();
        // instead of a cube we're going to use the par_shape parametric plane functions to create a cube instead
        // to get the texture coordinates which we don't with cubes
        var cube = zmesh.Shape.initPlane(1, 1);
        defer cube.deinit();
        cube.rotate(std.math.pi * 0.5, 1.0, 0.0, 0.0);
        cube.translate(0.0, 1.0, 0.0);
        // we need five planes to finish the cube since it has 6 faces
        var plane = zmesh.Shape.initPlane(1, 1);
        defer plane.deinit();
        plane.rotate(std.math.pi * 0.5, 0.0, 1.0, 0.0);
        plane.translate(1.0, 0.0, 1.0);
        cube.merge(plane);
        plane.rotate(std.math.pi * 0.5, 0.0, 1.0, 0.0);
        plane.translate(0.0, 0.0, 1.0);
        cube.merge(plane);
        plane.rotate(std.math.pi * 0.5, 0.0, 1.0, 0.0);
        plane.translate(0.0, 0.0, 1.0);
        cube.merge(plane);
        plane.rotate(std.math.pi * 0.5, 0.0, 1.0, 0.0);
        plane.translate(0.0, 0.0, 1.0);
        cube.merge(plane);
        plane.rotate(std.math.pi * 0.5, 1.0, 0.0, 0.0);
        plane.translate(0.0, 1.0, 0.0);
        cube.merge(plane);

        const vertexShaderSource = @embedFile("shaders/cube.vs");
        const fragmentShaderSource = @embedFile("shaders/cube.fs");
        const textureSource = @embedFile("assets/textures/grass.png");

        const s = try shape.Shape.init(
            name,
            cube,
            vertexShaderSource,
            fragmentShaderSource,
            textureSource,
            null,
            shape.ShapeConfig{ .hasTexture = true, .isCube = true },
            alloc,
        );
        return Cube{
            .name = name,
            .position = pos,
            .shape = s,
        };
    }

    pub fn deinit(self: Cube) void {
        self.shape.deinit();
    }

    pub fn draw(self: Cube, givenM: zm.Mat) !void {
        // move to world space with position
        const m = zm.translation(self.position.x, self.position.y, self.position.z);
        try self.shape.draw(zm.mul(m, givenM));
    }
};
