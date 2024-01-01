const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const shape = @import("shape.zig");
const instancedShape = @import("instanced_shape.zig");
const position = @import("../position.zig");
const state = @import("../state.zig");
const data = @import("../data/data.zig");

fn initParShapeCubeFromPlanes() zmesh.Shape {
    var cube = zmesh.Shape.initPlane(1, 1);
    cube.rotate(std.math.pi * 1.5, 1.0, 0.0, 0.0);
    cube.translate(0.0, 1.0, 1.0);
    // we need five planes to finish the cube since it has 6 faces
    var plane = zmesh.Shape.initPlane(1, 1);
    defer plane.deinit();
    plane.rotate(std.math.pi * 2 * 0.5, 0.0, 0.0, 1.0);
    plane.translate(1.0, 1.0, 1.0);
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
    plane.rotate(std.math.pi * 0.5, 0.0, 0.0, 1.0);
    plane.translate(1.0, 0.0, 0.0);
    cube.merge(plane);

    return cube;
}

pub const Cube = struct {
    fn initShape(
        name: []const u8,
        blockId: u32,
        alloc: std.mem.Allocator,
        textureRGBAColors: []const gl.Uint,
    ) !shape.Shape {
        const vertexShaderSource = @embedFile("../shaders/cube.vs");
        const fragmentShaderSource = @embedFile("../shaders/cube.fs");

        const sconfig = shape.ShapeConfig{
            .textureType = shape.textureDataType.RGBAColor,
            .isCube = true,
            .hasPerspective = true,
        };
        const cube = initParShapeCubeFromPlanes();
        defer cube.deinit();

        return try shape.Shape.init(
            blockId,
            name,
            cube,
            vertexShaderSource,
            fragmentShaderSource,
            null,
            null,
            textureRGBAColors,
            sconfig,
            alloc,
        );
    }

    fn initInstancedShape(
        name: []const u8,
        blockId: u32,
        alloc: std.mem.Allocator,
        textureRGBAColors: []const gl.Uint,
    ) !instancedShape.InstancedShape {
        const vertexShaderSource = @embedFile("../shaders/cube.vs");
        const fragmentShaderSource = @embedFile("../shaders/cube.fs");

        const cube = initParShapeCubeFromPlanes();
        defer cube.deinit();

        return try instancedShape.InstancedShape.init(
            blockId,
            name,
            cube,
            vertexShaderSource,
            fragmentShaderSource,
            null,
            textureRGBAColors,
            alloc,
        );
    }

    pub fn initDemoCubeShape(
        name: []const u8,
        alloc: std.mem.Allocator,
        textureRGBAColors: [data.RGBAColorTextureSize]gl.Uint,
    ) !shape.Shape {
        return try initShape(name, 0, alloc, &textureRGBAColors);
    }

    pub fn initBlockCube(appState: *state.State, blockId: u32, alloc: std.mem.Allocator, cubesMap: *std.AutoHashMap(u32, instancedShape.InstancedShape)) !void {
        var blockData: data.block = undefined;
        try appState.db.loadBlock(blockId, &blockData);
        var name = [_]u8{0} ** data.maxBlockSizeName;
        for (blockData.name, 0..) |c, i| {
            if (i >= data.maxBlockSizeName) {
                break;
            }
            name[i] = c;
        }
        const s = try initInstancedShape(&name, blockId, alloc, &blockData.texture);
        try cubesMap.put(blockId, s);
    }

    pub fn draw(x: gl.Float, y: gl.Float, z: gl.Float, givenM: zm.Mat, s: shape.Shape) !void {
        const m = zm.translation(x, y, z);
        try s.draw(zm.mul(m, givenM));
    }

    pub fn drawInstanced(x: gl.Float, y: gl.Float, z: gl.Float, givenM: zm.Mat, s: instancedShape.InstancedShape) !void {
        const m = zm.translation(x, y, z);
        try s.draw(zm.mul(m, givenM));
    }
};
