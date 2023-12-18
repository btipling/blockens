const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const shape = @import("shape.zig");
const position = @import("position.zig");

// Plane - this is a ground world plane for now
pub const Plane = struct {
    name: []const u8,
    position: position.Position,
    shape: shape.Shape,

    pub fn init(name: []const u8, planePosition: position.Position, alloc: std.mem.Allocator) !Plane {
        var plane = zmesh.Shape.initPlane(1, 1);
        defer plane.deinit();
        plane.rotate(std.math.pi * 1.5, 1.0, 0.0, 0.0);

        const vertexShaderSource = @embedFile("shaders/plane.vs");
        const fragmentShaderSource = @embedFile("shaders/plane.fs");
        const groundColor: [4]gl.Float = [_]gl.Float{ 34.0 / 255.0, 32.0 / 255.0, 52.0 / 255.0, 1.0 };

        const s = try shape.Shape.init(
            name,
            plane,
            vertexShaderSource,
            fragmentShaderSource,
            null,
            groundColor,
            shape.ShapeConfig{ .hasTexture = true, .isCube = false, .hasPerspective = true },
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
        m = zm.mul(m, zm.translation(-100.0, -0.001, 100.0));
        m = zm.mul(m, zm.translation(self.position.x, self.position.y, self.position.z));
        try self.shape.draw(zm.mul(m, givenM));
    }
};
