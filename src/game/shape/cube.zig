const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const shape = @import("shape.zig");
const position = @import("../position.zig");
const state = @import("../state.zig");
const data = @import("../data/data.zig");

var cubesMap: ?std.AutoHashMap(u32, shape.Shape) = null;

pub const Cube = struct {
    blockId: u32,
    position: position.Position,
    shape: shape.Shape,

    fn initShape(
        name: []const u8,
        blockId: u32,
        alloc: std.mem.Allocator,
        textureRGBAColors: []const gl.Uint,
    ) !shape.Shape {
        // instead of a cube we're going to use the par_shape parametric plane functions to create a cube instead
        // to get the texture coordinates which we don't with cubes
        var cube = zmesh.Shape.initPlane(1, 1);
        defer cube.deinit();
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

        const vertexShaderSource = @embedFile("../shaders/cube.vs");
        const fragmentShaderSource = @embedFile("../shaders/cube.fs");

        const sconfig = shape.ShapeConfig{
            .textureType = shape.textureDataType.RGBAColor,
            .isCube = true,
            .hasPerspective = true,
        };

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

    pub fn initDemoCube(
        name: []const u8,
        pos: position.Position,
        alloc: std.mem.Allocator,
        textureRGBAColors: [data.RGBAColorTextureSize]gl.Uint,
    ) !Cube {
        const s = try initShape(name, 0, alloc, &textureRGBAColors);
        return Cube{
            .blockId = 0,
            .position = pos,
            .shape = s,
        };
    }

    pub fn initBlockCube(appState: *state.State, blockId: u32, pos: position.Position, alloc: std.mem.Allocator) !Cube {
        var blockData: data.block = undefined;
        try appState.db.loadBlock(blockId, &blockData);
        var name = [_]u8{0} ** data.maxBlockSizeName;
        for (blockData.name, 0..) |c, i| {
            if (i >= data.maxBlockSizeName) {
                break;
            }
            name[i] = c;
        }
        const s = try initShape(&name, blockId, alloc, &blockData.texture);
        try cubesMap.?.put(blockId, s);
        return Cube{
            .blockId = blockId,
            .position = pos,
            .shape = s,
        };
    }

    pub fn init(appState: *state.State, blockId: u32, pos: position.Position, alloc: std.mem.Allocator) !Cube {
        if (cubesMap) |m| {
            if (m.get(blockId)) |s| {
                return Cube{
                    .blockId = blockId,
                    .position = pos,
                    .shape = s,
                };
            } else {
                return try initBlockCube(appState, blockId, pos, alloc);
            }
        }
        cubesMap = std.AutoHashMap(u32, shape.Shape).init(alloc);
        return try initBlockCube(appState, blockId, pos, alloc);
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
        const m = zm.translation(self.position.x, self.position.y, self.position.z);
        try self.shape.draw(zm.mul(m, givenM));
    }
};
