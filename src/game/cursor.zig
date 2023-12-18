const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const shape = @import("shape.zig");
const position = @import("position.zig");

pub const Cursor = struct {
    name: []const u8,
    position: position.Position,
    shape: shape.Shape,

    pub fn init(name: []const u8, planePosition: position.Position, alloc: std.mem.Allocator) !Cursor {
        var crosshair = zmesh.Shape.initPlane(1, 1);
        defer crosshair.deinit();
        crosshair.translate(-0.5, -0.5, 0.0);
        crosshair.scale(0.005, 0.05, 1.0);
        var plane = zmesh.Shape.initPlane(1, 1);
        defer plane.deinit();
        plane.translate(-0.5, -0.5, 0.0);
        plane.scale(0.05, 0.005, 1.0);
        crosshair.merge(plane);

        const vertexShaderSource = @embedFile("shaders/cursor.vs");
        const fragmentShaderSource = @embedFile("shaders/cursor.fs");
        const cursorColor: [4]gl.Float = [_]gl.Float{ 0.0, 0.0, 0.0, 1.0 };

        const s = try shape.Shape.init(
            name,
            crosshair,
            vertexShaderSource,
            fragmentShaderSource,
            null,
            cursorColor,
            shape.ShapeConfig{ .hasTexture = true, .isCube = false, .hasPerspective = false },
            alloc,
        );
        return Cursor{
            .name = name,
            .position = planePosition,
            .shape = s,
        };
    }

    pub fn deinit(self: *Cursor) void {
        self.shape.deinit();
    }

    pub fn draw(self: *Cursor, _: zm.Mat) !void {
        var m = zm.scaling(0.2, 0.25, 1.0);
        m = zm.mul(m, zm.translation(-0.01, 0.0, -0.5));
        try self.shape.draw(m);
    }
};
