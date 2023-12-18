const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const shape = @import("shape.zig");
const position = @import("position.zig");

const grassTexture = @embedFile("assets/textures/grass.png");
const stoneTexture = @embedFile("assets/textures/stone.png");
const sandTexture = @embedFile("assets/textures/sand.png");
const oreTexture = @embedFile("assets/textures/ore.png");

pub const CubeType = enum {
    grass,
    stone,
    sand,
    ore,
};

var cubesMap: ?std.AutoHashMap(CubeType, shape.Shape) = null;

pub const Cube = struct {
    name: []const u8,
    type: CubeType,
    position: position.Position,
    shape: shape.Shape,

    fn initShape(name: []const u8, cubeType: CubeType, alloc: std.mem.Allocator) !shape.Shape {
        // instead of a cube we're going to use the par_shape parametric plane functions to create a cube instead
        // to get the texture coordinates which we don't with cubes
        var cube = zmesh.Shape.initPlane(1, 1);
        defer cube.deinit();
        cube.rotate(std.math.pi * 1.5, 1.0, 0.0, 0.0);
        cube.translate(0.0, 1.0, 1.0);
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

        var textureSource: ?[:0]const u8 = null;
        switch (cubeType) {
            CubeType.grass => textureSource = grassTexture,
            CubeType.stone => textureSource = stoneTexture,
            CubeType.sand => textureSource = sandTexture,
            else => textureSource = oreTexture,
        }

        return try shape.Shape.init(
            name,
            cube,
            vertexShaderSource,
            fragmentShaderSource,
            textureSource,
            null,
            shape.ShapeConfig{ .hasTexture = true, .isCube = true, .hasPerspective = true },
            alloc,
        );
    }

    pub fn init(name: []const u8, cubeType: CubeType, pos: position.Position, alloc: std.mem.Allocator) !Cube {
        if (cubesMap) |m| {
            if (m.get(cubeType)) |s| {
                return Cube{
                    .type = cubeType,
                    .name = name,
                    .position = pos,
                    .shape = s,
                };
            } else {
                const s = try initShape(name, cubeType, alloc);
                try cubesMap.?.put(cubeType, s);
                return Cube{
                    .type = cubeType,
                    .name = name,
                    .position = pos,
                    .shape = s,
                };
            }
        }

        cubesMap = std.AutoHashMap(CubeType, shape.Shape).init(
            alloc,
        );

        const s = try initShape(name, cubeType, alloc);
        try cubesMap.?.put(cubeType, s);
        return Cube{
            .type = cubeType,
            .name = name,
            .position = pos,
            .shape = s,
        };
    }

    pub fn deinit(_: Cube) void {
        if (cubesMap) |m| {
            var iterator = m.iterator();
            while (iterator.next()) |s| {
                s.value_ptr.deinit();
            }
            cubesMap.?.deinit();
            cubesMap = null;
        }
    }

    pub fn draw(self: Cube, givenM: zm.Mat) !void {
        // move to world space with position
        const m = zm.translation(self.position.x, self.position.y, self.position.z);
        try self.shape.draw(zm.mul(m, givenM));
    }
};
