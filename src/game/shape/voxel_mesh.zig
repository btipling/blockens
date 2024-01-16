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
    .{ -0.5, -0.5, 0.5 },
    .{ 0.5, -0.5, 0.5 },
    .{ 0.5, 0.5, 0.5 },
    .{ -0.5, -0.5, 0.5 },
    .{ 0.5, 0.5, 0.5 },
    .{ -0.5, 0.5, 0.5 },

    // right
    .{ 0.5, -0.5, 0.5 },
    .{ 0.5, -0.5, -0.5 },
    .{ 0.5, 0.5, -0.5 },
    .{ 0.5, -0.5, 0.5 },
    .{ 0.5, 0.5, -0.5 },
    .{ 0.5, 0.5, 0.5 },
    // back
    .{ 0.5, -0.5, -0.5 },
    .{ -0.5, -0.5, -0.5 },
    .{ -0.5, 0.5, -0.5 },
    .{ 0.5, -0.5, -0.5 },
    .{ -0.5, 0.5, -0.5 },
    .{ 0.5, 0.5, -0.5 },
    // left
    .{ -0.5, -0.5, -0.5 },
    .{ -0.5, -0.5, 0.5 },
    .{ -0.5, 0.5, 0.5 },
    .{ -0.5, -0.5, -0.5 },
    .{ -0.5, 0.5, 0.5 },
    .{ -0.5, 0.5, -0.5 },
    // bottom
    .{ -0.5, -0.5, -0.5 },
    .{ 0.5, -0.5, -0.5 },
    .{ 0.5, -0.5, 0.5 },
    .{ -0.5, -0.5, -0.5 },
    .{ 0.5, -0.5, 0.5 },
    .{ -0.5, -0.5, 0.5 },
    // top
    .{ -0.5, 0.5, 0.5 },
    .{ 0.5, 0.5, 0.5 },
    .{ 0.5, 0.5, -0.5 },
    .{ -0.5, 0.5, 0.5 },
    .{ 0.5, 0.5, -0.5 },
    .{ -0.5, 0.5, -0.5 },
};

const indices: [36]u32 = .{
    0, 1, 2, 3, 4, 5, // front
    6, 7, 8, 9, 10, 11, // right
    12, 13, 14, 15, 16, 17, // back
    18, 19, 20, 21, 22, 23, // left
    24, 25, 26, 27, 28, 29, // bottom
    30, 31, 32, 33, 34, 35, // top
};

const texcoords: [36][2]gl.Float = .{
    // front
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
    // right
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
    // back
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
    // left
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
    // bottom
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 1.0 },
    .{ 0.0, 0.666 },
    .{ 1.0, 1.0 },
    .{ 0.0, 1.0 },
    // top
    .{ 0.0, 0.0 },
    .{ 1.0, 0.0 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.0 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
};

const normals: [36][3]gl.Float = .{
    // front
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    // right
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    // backl
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    // left
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    // bottom
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    // top
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
};

pub const VoxelMesh = struct {
    blockId: i32,
    voxelShape: voxelShape.VoxelShape,
    voxel: zmesh.Shape,
    currentVoxel: zmesh.Shape,

    pub fn init(
        appState: *state.State,
        vm: view.View,
        blockId: i32,
        alloc: std.mem.Allocator,
    ) !VoxelMesh {
        var block: data.block = undefined;
        try appState.db.loadBlock(blockId, &block);

        var indicesAL = std.ArrayList(u32).init(alloc);
        defer indicesAL.deinit();
        var _i = indices;
        try indicesAL.appendSlice(&_i);

        var positionsAL = std.ArrayList([3]gl.Float).init(alloc);
        defer positionsAL.deinit();
        var _p = positions;
        try positionsAL.appendSlice(&_p);

        var normalsAL = std.ArrayList([3]gl.Float).init(alloc);
        defer normalsAL.deinit();
        var _n = normals;
        try normalsAL.appendSlice(&_n);

        var texcoordsAL = std.ArrayList([2]gl.Float).init(alloc);
        defer texcoordsAL.deinit();
        var _t = texcoords;
        try texcoordsAL.appendSlice(&_t);

        const vertexShaderSource = @embedFile("../shaders/voxel.vs");
        const fragmentShaderSource = @embedFile("../shaders/voxel.fs");

        const vs = try voxelShape.VoxelShape.init(
            vm,
            blockId,
            vertexShaderSource,
            fragmentShaderSource,
            &block.texture,
            alloc,
        );
        const voxel = zmesh.Shape.init(indicesAL, positionsAL, normalsAL, texcoordsAL);
        return .{
            .blockId = blockId,
            .voxelShape = vs,
            .voxel = voxel,
            .currentVoxel = voxel,
        };
    }

    pub fn deinit(self: *VoxelMesh) void {
        self.voxelShape.deinit();
        self.voxel.deinit();
    }

    pub fn clear(self: *VoxelMesh) void {
        self.voxelShape.clear();
    }

    pub fn initVoxel(
        self: *VoxelMesh,
    ) !void {
        var v = self.voxel;
        var __v = &v;
        // voxel meshes are centered around origin and range fro -0.5 to 0.5 so need a translation
        __v.translate(0.5, 0.5, 0.5);
        self.currentVoxel = __v.*;
    }

    pub fn expandVoxelX(self: *VoxelMesh) void {
        var v = self.currentVoxel;
        var __v = &v;
        // scale(mesh: *Shape, x: f32, y: f32, z: f32) void {
        __v.scale(2.0, 1.0, 1.0);
        self.currentVoxel = __v.*;
    }

    pub fn writeVoxel(
        self: *VoxelMesh,
        worldTransform: [16]gl.Float,
    ) !void {
        try self.voxelShape.addVoxelData(self.currentVoxel, worldTransform);
        self.currentVoxel = self.voxel;
    }

    pub fn draw(self: *VoxelMesh) !void {
        try self.voxelShape.draw();
    }
};
