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
    meshMap: std.AutoHashMap(gltf.MutCString, u32),
    fileData: *gltf.Data, // managed by zmesh.io
    datas: std.ArrayList(mobShape.MobShapeData),
    alloc: std.mem.Allocator,

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
            .meshMap = std.AutoHashMap(gltf.MutCString, u32).init(alloc),
            .fileData = fileData,
            .datas = datas,
            .alloc = alloc,
        };
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
        var mm = self.meshMap;
        _ = &mm;
        mm.deinit();
    }

    // if (fileData.meshes) |m| {
    //     std.debug.print("num_nodes: {d}\n", .{fileData.nodes_count});

    //     for (0..fileData.meshes_count) |i| {
    //
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

    pub fn mapMeshesByName(self: *MobMesh) !void {
        const fileData = self.fileData;
        if (fileData.meshes) |m| {
            for (0..fileData.meshes_count) |i| {
                const meshId = @as(u32, @intCast(i));
                const mesh: gltf.Mesh = m[i];
                const name = mesh.name orelse {
                    std.debug.print("no name for mesh at {d}\n", .{i});
                    continue;
                };
                try self.meshMap.put(name, meshId);
            }
        }
    }

    pub fn build(self: *MobMesh) !void {
        try self.mapMeshesByName();
        const defaultScene = self.fileData.scene orelse {
            std.debug.print("no default scene\n", .{});
            return MobMeshErr.NoScenes;
        };
        try self.buildScene(defaultScene);
    }

    pub fn buildScene(self: *MobMesh, scene: *gltf.Scene) !void {
        const sceneName = scene.name orelse {
            std.debug.print("no name for scene\n", .{});
            return;
        };
        std.debug.print("building scene: {s}\n", .{sceneName});
        var nodes: [*]*gltf.Node = undefined;
        const T = @TypeOf(scene.nodes);
        nodes = switch (T) {
            ?[*]*gltf.Node => scene.nodes orelse {
                std.debug.print("{s} has no nodes\n", .{sceneName});
                return MobMeshErr.BuildErr;
            },
            else => {
                std.debug.print("{s} has no nodes T is {}\n", .{ sceneName, T });
                return MobMeshErr.BuildErr;
            },
        };
        for (0..scene.nodes_count) |i| {
            const node: *gltf.Node = nodes[i];
            try self.buildNode(node);
        }
    }

    pub fn buildNode(self: *MobMesh, node: *gltf.Node) !void {
        const nodeName = node.name orelse {
            std.debug.print("no name for node\n", .{});
            return;
        };
        std.debug.print("building node: {s}\n", .{nodeName});
        const mesh = node.mesh orelse {
            std.debug.print("{s} no mesh\n", .{nodeName});
            return;
        };
        try self.buildMesh(nodeName, mesh);

        var nodes: [*]*gltf.Node = undefined;
        const T = @TypeOf(node.children);
        nodes = switch (T) {
            ?[*]*gltf.Node => node.children orelse {
                std.debug.print("node {s} has no children\n", .{nodeName});
                return;
            },
            else => {
                std.debug.print("{s} has no children T is {}\n", .{ nodeName, T });
                return;
            },
        };
        for (0..node.children_count) |i| {
            const child: *gltf.Node = nodes[i];
            try self.buildNode(child);
        }
    }

    pub fn buildMesh(self: *MobMesh, nodeName: [*:0]const u8, mesh: *gltf.Mesh) !void {
        const meshName = mesh.name orelse {
            std.debug.print("{s} mesh has no name\n", .{nodeName});
            return;
        };
        const meshId = self.meshMap.get(meshName) orelse {
            std.debug.print("{s}'s mesh {s} not found\n", .{ nodeName, meshName });
            return;
        };
        var mobShapeData = mobShape.MobShapeData.init(self.alloc);
        try zmesh.io.appendMeshPrimitive(
            self.fileData, // *zmesh.io.cgltf.Data
            meshId, // mesh index
            0, // gltf primitive index (submesh index)
            &mobShapeData.indices,
            &mobShapeData.positions,
            &mobShapeData.normals, // normals (optional)
            null, // texcoords (optional)
            null, // tangents (optional)
        );
        try self.mob.addMeshData(meshId, mobShapeData);
    }

    pub fn draw(self: *MobMesh) !void {
        try self.mob.draw();
    }
};
