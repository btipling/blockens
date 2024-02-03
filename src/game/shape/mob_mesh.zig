const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const mobShape = @import("mob_shape.zig");
const view = @import("./view.zig");
const state = @import("../state/state.zig");
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

pub const MobMesh = struct {
    mobId: i32,
    mob: mobShape.MobShape,
    shape: zmesh.Shape,

    pub fn init(
        vm: view.View,
        mobId: i32,
        alloc: std.mem.Allocator,
    ) !MobMesh {
        var indicesAL = std.ArrayList(u32).init(alloc);
        defer indicesAL.deinit();
        var _i = indices;
        try indicesAL.appendSlice(&_i);

        var positionsAL = std.ArrayList([3]gl.Float).init(alloc);
        defer positionsAL.deinit();
        var _p = positions;
        try positionsAL.appendSlice(&_p);

        const vertexShaderSource = @embedFile("../shaders/mob.vs");
        const fragmentShaderSource = @embedFile("../shaders/mob.fs");

        const mob = try mobShape.MobShape.init(
            vm,
            mobId,
            vertexShaderSource,
            fragmentShaderSource,
            alloc,
        );
        const shape = zmesh.Shape.init(indicesAL, positionsAL, null, null);
        return .{
            .mobId = mobId,
            .mob = mob,
            .shape = shape,
        };
    }

    pub fn deinit(self: MobMesh) void {
        self.shape.deinit();
        self.mob.deinit();
    }

    pub fn generate(self: *MobMesh) !void {
        const _s = self.shape.clone();
        defer _s.deinit();
        try self.mob.addMobData(_s);
        return;
    }

    pub fn draw(self: *MobMesh) !void {
        try self.mob.draw();
    }
};
