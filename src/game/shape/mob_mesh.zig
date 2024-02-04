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
    parts: std.ArrayList(mobShape.MobShape),
    datas: std.ArrayList(mobShape.MobShapeData),

    pub fn init(
        vm: view.View,
        mobId: i32,
        alloc: std.mem.Allocator,
    ) !MobMesh {
        const vertexShaderSource = @embedFile("../shaders/mob.vs");
        const fragmentShaderSource = @embedFile("../shaders/mob.fs");

        const fileData = try zmesh.io.parseAndLoadFile("./src/game/shape/cgltf/char.glb");
        defer zmesh.io.freeData(fileData);

        var parts = std.ArrayList(mobShape.MobShape).init(alloc);
        var datas = std.ArrayList(mobShape.MobShapeData).init(alloc);

        if (fileData.meshes) |m| {
            std.debug.print("num_nodes: {d}\n", .{fileData.nodes_count});

            for (0..fileData.meshes_count) |i| {
                var mobShapeData = mobShape.MobShapeData.init(alloc);
                const mesh: zmesh.io.zcgltf.Mesh = m[i];
                std.debug.print("mesh at {d} {s}\n", .{ i, mesh.name orelse "nothing" });

                try zmesh.io.appendMeshPrimitive(
                    fileData, // *zmesh.io.cgltf.Data
                    @as(u32, @intCast(i)), // mesh index
                    0, // gltf primitive index (submesh index)
                    &mobShapeData.indices,
                    &mobShapeData.positions,
                    &mobShapeData.normals, // normals (optional)
                    null, // texcoords (optional)
                    null, // tangents (optional)
                );
                try datas.append(mobShapeData);

                var part = try mobShape.MobShape.init(
                    vm,
                    mobId,
                    vertexShaderSource,
                    fragmentShaderSource,
                    alloc,
                );
                try mobShape.MobShape.addMobData(&part, &mobShapeData);
                try parts.append(part);
            }
        }
        return .{
            .mobId = mobId,
            .parts = parts,
            .datas = datas,
        };
    }

    pub fn deinit(self: MobMesh) void {
        for (self.datas.items) |d| {
            d.deinit();
        }
        self.datas.deinit();
        for (self.parts.items) |p| {
            p.deinit();
        }
        self.parts.deinit();
    }

    pub fn generate(self: *MobMesh) !void {
        _ = self;
        return;
    }

    pub fn draw(self: *MobMesh) !void {
        for (self.parts.items) |p| {
            try p.draw();
        }
    }
};
