const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const mobShape = @import("mob_shape.zig");
const view = @import("./view.zig");
const state = @import("../state/state.zig");
const data = @import("../data/data.zig");
const gltf = zmesh.io.zcgltf;

pub const MobMeshErr = error{
    NoScenes,
    BuildErr,
};

pub const MobMesh = struct {
    mobId: i32,
    mob: mobShape.MobShape,
    fileData: *gltf.Data, // managed by zmesh.io
    datas: std.ArrayList(mobShape.MobShapeData),

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
        const fileData = try zmesh.io.parseAndLoadFile("./src/game/shape/cgltf/char.glb");
        const datas = std.ArrayList(mobShape.MobShapeData).init(alloc);

        return .{
            .mobId = mobId,
            .mob = mob,
            .fileData = fileData,
            .datas = datas,
        };
    }

    // if (fileData.meshes) |m| {
    //     std.debug.print("num_nodes: {d}\n", .{fileData.nodes_count});

    //     for (0..fileData.meshes_count) |i| {
    //         var mobShapeData = mobShape.MobShapeData.init(alloc);
    //         const mesh: zmesh.io.zcgltf.Mesh = m[i];
    //         std.debug.print("mesh at {d} {s}\n", .{ i, mesh.name orelse "nothing" });

    //         try zmesh.io.appendMeshPrimitive(
    //             fileData, // *zmesh.io.cgltf.Data
    //             @as(u32, @intCast(i)), // mesh index
    //             0, // gltf primitive index (submesh index)
    //             &mobShapeData.indices,
    //             &mobShapeData.positions,
    //             &mobShapeData.normals, // normals (optional)
    //             null, // texcoords (optional)
    //             null, // tangents (optional)
    //         );
    //         try datas.append(mobShapeData);

    //
    //         try mobShape.MobShape.addMobData(&part, &mobShapeData);
    //         try parts.append(part);
    //     }
    // }

    pub fn build(self: *MobMesh) !void {
        const defaultScene = self.fileData.scene orelse {
            std.debug.print("no default scene\n", .{});
            return MobMeshErr.NoScenes;
        };
        std.debug.print("default scene: {s}\n", .{defaultScene.name orelse "no name"});
    }

    pub fn deinit(self: MobMesh) void {
        for (self.datas.items) |d| {
            d.deinit();
        }
        self.datas.deinit();
        var mob = self.mob;
        _ = &mob;
        mob.deinit();
        var fd = self.fileData;
        _ = &fd;
        zmesh.io.freeData(fd);
    }

    pub fn draw(self: *MobMesh) !void {
        try self.mob.draw();
    }
};
