const std = @import("std");
const gl = @import("zopengl").bindings;
const zm = @import("zmath");
const zmesh = @import("zmesh");
const shape = @import("shape.zig");

pub const Cursor = struct {
    name: []const u8,
    shape: shape.Shape,

    pub fn init(name: []const u8, alloc: std.mem.Allocator) !Cursor {
        var crosshair = zmesh.Shape.initPlane(1, 1);
        defer crosshair.deinit();
        crosshair.translate(-0.5, -0.5, 0.0);
        crosshair.scale(0.005, 0.05, 1.0);
        var plane = zmesh.Shape.initPlane(1, 1);
        defer plane.deinit();
        plane.translate(-0.5, -0.5, 0.0);
        plane.scale(0.05, 0.005, 1.0);
        crosshair.merge(plane);

        const vertexShaderSource = @embedFile("../shaders/cursor.vs");
        const fragmentShaderSource = @embedFile("../shaders/cursor.fs");
        const cursorColor: [4]gl.Float = [_]gl.Float{ 0.0, 0.0, 0.0, 1.0 };

        const s = try shape.Shape.init(
            0,
            name,
            crosshair,
            vertexShaderSource,
            fragmentShaderSource,
            null,
            cursorColor,
            null,
            shape.ShapeConfig{ .textureType = shape.textureDataType.Image, .isCube = false, .hasPerspective = false },
            alloc,
        );
        return Cursor{
            .name = name,
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
