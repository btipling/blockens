const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const shape = @import("shape.zig");
const position = @import("position.zig");

// Plane - this is a grassy world plane for now
pub const Plane = struct {
    name: []const u8,
    position: position.Position,
    shape: shape.Shape,

    pub fn init(name: []const u8, planePosition: position.Position, alloc: std.mem.Allocator) !Plane {
        // var cube = zmesh.Shape.initCube();
        // defer cube.deinit();
        // instead of a cube we're going to use the par_shape parametric plane functions to create a cube instead
        // to get the texture coordinates which we don't with cubes
        var plane = zmesh.Shape.initPlane(1, 1);
        defer plane.deinit();
        plane.rotate(std.math.pi * 0.5, 1.0, 0.0, 0.0);

        const vertexShaderSource = @embedFile("shaders/plane.vs");
        const fragmentShaderSource = @embedFile("shaders/plane.fs");
        const grassColor: [4]gl.Float = [_]gl.Float{ 0.0, 0.5, 0.0, 1.0 };

        const s = try shape.Shape.init(
            name,
            plane,
            vertexShaderSource,
            fragmentShaderSource,
            null,
            grassColor,
            shape.ShapeConfig{ .hasTexture = true },
            alloc,
        );
        return Plane{
            .name = name,
            .position = planePosition,
            .shape = s,
        };
    }

    pub fn deinit(self: *Plane) void {
        self.shape.deinit();
    }

    pub fn draw(self: *Plane, givenM: zm.Mat) !void {
        var m = zm.scaling(200.0, 200.0, 200.0);
        m = zm.mul(m, zm.translation(-100.0, -0.001, -100.0));
        m = zm.mul(m, zm.translation(self.position.x, self.position.y, self.position.z));
        try self.shape.draw(zm.mul(m, givenM));
    }
};
