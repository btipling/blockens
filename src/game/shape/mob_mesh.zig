const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const mobShape = @import("mob_shape.zig");
const view = @import("./view.zig");
const state = @import("../state/state.zig");
const data = @import("../data/data.zig");

pub const MobMesh = struct {
    mobId: i32,
    mob: mobShape.MobShape,
    mobShapeData: mobShape.MobShapeData,

    pub fn init(
        vm: view.View,
        mobId: i32,
        alloc: std.mem.Allocator,
    ) !MobMesh {
        const vertexShaderSource = @embedFile("../shaders/mob.vs");
        const fragmentShaderSource = @embedFile("../shaders/mob.fs");

        const mob = try mobShape.MobShape.init(
            vm,
            mobId,
            vertexShaderSource,
            fragmentShaderSource,
            alloc,
        );

        var mobShapeData = mobShape.MobShapeData.init(alloc);

        const fileData = try zmesh.io.parseAndLoadFile("./src/game/shape/cgltf/char.glb");
        defer zmesh.io.freeData(fileData);

        try zmesh.io.appendMeshPrimitive(
            fileData, // *zmesh.io.cgltf.Data
            0, // mesh index
            0, // gltf primitive index (submesh index)
            &mobShapeData.indices,
            &mobShapeData.positions,
            &mobShapeData.normals, // normals (optional)
            null, // texcoords (optional)
            null, // tangents (optional)
        );

        return .{
            .mobId = mobId,
            .mob = mob,
            .mobShapeData = mobShapeData,
        };
    }

    pub fn deinit(self: MobMesh) void {
        self.mobShapeData.deinit();
        self.mob.deinit();
    }

    pub fn generate(self: *MobMesh) !void {
        try self.mob.addMobData(&self.mobShapeData);
        return;
    }

    pub fn draw(self: *MobMesh) !void {
        try self.mob.draw();
    }
};
