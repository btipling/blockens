const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const voxelShape = @import("voxel_shape.zig");
const position = @import("../position.zig");
const view = @import("./view.zig");
const state = @import("../state.zig");
const data = @import("../data/data.zig");

const positions: [36][3]gl.Float = .{
    // front
    .{ -1.0, -1.0, 1.0 },
    .{ 1.0, -1.0, 1.0 },
    .{ 1.0, 1.0, 1.0 },
    .{ -1.0, -1.0, 1.0 },
    .{ 1.0, 1.0, 1.0 },
    .{ -1.0, 1.0, 1.0 },
    // right
    .{ 1.0, -1.0, 1.0 },
    .{ 1.0, -1.0, -1.0 },
    .{ 1.0, 1.0, -1.0 },
    .{ 1.0, -1.0, 1.0 },
    .{ 1.0, 1.0, -1.0 },
    .{ 1.0, 1.0, 1.0 },
    // back
    .{ 1.0, -1.0, -1.0 },
    .{ -1.0, -1.0, -1.0 },
    .{ -1.0, 1.0, -1.0 },
    .{ 1.0, -1.0, -1.0 },
    .{ -1.0, 1.0, -1.0 },
    .{ 1.0, 1.0, -1.0 },
    // left
    .{ -1.0, -1.0, -1.0 },
    .{ -1.0, -1.0, 1.0 },
    .{ -1.0, 1.0, 1.0 },
    .{ -1.0, -1.0, -1.0 },
    .{ -1.0, 1.0, 1.0 },
    .{ -1.0, 1.0, -1.0 },
    // bottom
    .{ -1.0, -1.0, -1.0 },
    .{ 1.0, -1.0, -1.0 },
    .{ 1.0, -1.0, 1.0 },
    .{ -1.0, -1.0, -1.0 },
    .{ 1.0, -1.0, 1.0 },
    .{ -1.0, -1.0, 1.0 },
    // top
    .{ -1.0, 1.0, 1.0 },
    .{ 1.0, 1.0, 1.0 },
    .{ 1.0, 1.0, -1.0 },
    .{ -1.0, 1.0, 1.0 },
    .{ 1.0, 1.0, -1.0 },
    .{ -1.0, 1.0, -1.0 },
};

const indices: [36]gl.Uint = .{
    0, 1, 2, 3, 4, 5, // front
    6, 7, 8, 9, 10, 11, // right
    12, 13, 14, 15, 16, 17, // back
    18, 19, 20, 21, 22, 23, // left
    24, 25, 26, 27, 28, 29, // bottom
    30, 31, 32, 33, 34, 35, // top
};

const texcoords: [72]gl.Float = .{
    // front
    0.0, 0.666,
    1.0, 0.666,
    1.0, 1.0,
    0.0, 0.666,
    1.0, 1.0,
    0.0, 1.0,
    // right
    0.0, 0.666,
    1.0, 0.666,
    1.0, 1.0,
    0.0, 0.666,
    1.0, 1.0,
    0.0, 1.0,
    // back
    0.0, 0.666,
    1.0, 0.666,
    1.0, 1.0,
    0.0, 0.666,
    1.0, 1.0,
    0.0, 1.0,
    // left
    0.0, 0.666,
    1.0, 0.666,
    1.0, 1.0,
    0.0, 0.666,
    1.0, 1.0,
    0.0, 1.0,
    // bottom
    0.0, 0.333,
    1.0, 0.333,
    1.0, 0.666,
    0.0, 0.333,
    1.0, 0.666,
    0.0, 0.666,
    // top
    0.0, 0.0,
    1.0, 0.0,
    1.0, 0.333,
    0.0, 0.0,
    1.0, 0.333,
    0.0, 0.333,
};

const normals: [108]gl.Float = .{
    0.0,  0.0,  1.0, // front
    0.0,  0.0,  1.0,
    0.0,  0.0,  1.0,
    0.0,  0.0,  1.0,
    0.0,  0.0,  1.0,
    0.0,  0.0,  1.0,
    // right
    1.0,  0.0,  0.0,
    1.0,  0.0,  0.0,
    1.0,  0.0,  0.0,
    1.0,  0.0,  0.0,
    1.0,  0.0,  0.0,
    1.0,  0.0,  0.0,
    // backl
    0.0,  0.0,  -1.0,
    0.0,  0.0,  -1.0,
    0.0,  0.0,  -1.0,
    0.0,  0.0,  -1.0,
    0.0,  0.0,  -1.0,
    0.0,  0.0,  -1.0,
    // left
    -1.0, 0.0,  0.0,
    -1.0, 0.0,  0.0,
    -1.0, 0.0,  0.0,
    -1.0, 0.0,  0.0,
    -1.0, 0.0,  0.0,
    -1.0, 0.0,  0.0,
    // bottom
    0.0,  -1.0, 0.0,
    0.0,  -1.0, 0.0,
    0.0,  -1.0, 0.0,
    0.0,  -1.0, 0.0,
    0.0,  -1.0, 0.0,
    0.0,  -1.0, 0.0,
    // top
    0.0,  1.0,  0.0,
    0.0,  1.0,  0.0,
    0.0,  1.0,  0.0,
    0.0,  1.0,  0.0,
    0.0,  1.0,  0.0,
    0.0,  1.0,  0.0,
};

pub const VoxelMesh = struct {
    fn init(
        blockId: i32,
        alloc: std.mem.Allocator,
        textureRGBAColors: []const gl.Uint,
        worldTransform: [16]gl.Float,
    ) !voxelShape.VoxelShape {
        const vertexShaderSource = @embedFile("../shaders/voxel.vs");
        const fragmentShaderSource = @embedFile("../shaders/voxel.fs");

        // positions and indices for a cube

        var voxel = zmesh.Shape.init(indices, positions, normals, texcoords);
        defer voxel.deinit();

        return try voxelShape.VoxelShape.init(
            blockId,
            voxel,
            vertexShaderSource,
            fragmentShaderSource,
            textureRGBAColors,
            worldTransform,
            alloc,
        );
    }

    pub fn draw(s: *voxelShape.VoxelShape) !void {
        try s.draw();
    }
};
