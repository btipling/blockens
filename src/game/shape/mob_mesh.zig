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
        try self.texturesInfo();
        try self.mapMeshesByName();
        const defaultScene = self.fileData.scene orelse {
            std.debug.print("no default scene\n", .{});
            return MobMeshErr.NoScenes;
        };
        try self.buildScene(defaultScene);
    }

    pub fn texturesInfo(self: *MobMesh) !void {
        std.debug.print("building textures: {d}\n", .{self.fileData.textures_count});
        const textures = self.fileData.textures orelse {
            std.debug.print("no textures\n", .{});
            return;
        };
        for (0..self.fileData.textures_count) |i| {
            const texture: gltf.Texture = textures[i];
            try self.textureInfo(texture);
        }
    }

    pub fn textureInfo(_: *MobMesh, texture: gltf.Texture) !void {
        const textureName = texture.name orelse "no_texture_name";
        std.debug.print("building texture: {s}\n", .{textureName});
    }

    pub fn buildScene(self: *MobMesh, scene: *gltf.Scene) !void {
        var nodes: [*]*gltf.Node = undefined;
        const T = @TypeOf(scene.nodes);
        nodes = switch (T) {
            ?[*]*gltf.Node => scene.nodes orelse return MobMeshErr.BuildErr,
            else => return MobMeshErr.BuildErr,
        };
        for (0..scene.nodes_count) |i| {
            const node: *gltf.Node = nodes[i];
            try self.buildNode(node, zm.identity());
        }
    }
    pub fn buildNode(self: *MobMesh, node: *gltf.Node, parentTransform: zm.Mat) !void {
        const nodeName = node.name orelse return;
        const localTransform = zm.mul(parentTransform, transformFromNode(node, nodeName));
        const mesh = node.mesh orelse return;
        try self.buildMesh(nodeName, localTransform, mesh);

        var nodes: [*]*gltf.Node = undefined;
        const T = @TypeOf(node.children);
        nodes = switch (T) {
            ?[*]*gltf.Node => node.children orelse return,
            else => return,
        };
        for (0..node.children_count) |i| {
            const child: *gltf.Node = nodes[i];
            try self.buildNode(child, localTransform);
        }
    }

    pub fn buildMesh(self: *MobMesh, nodeName: [*:0]const u8, localTransform: zm.Mat, mesh: *gltf.Mesh) !void {
        const meshName = mesh.name orelse {
            return;
        };
        const meshId = self.meshMap.get(meshName) orelse {
            std.debug.print("{s}'s mesh {s} not found\n", .{ nodeName, meshName });
            return;
        };
        const bgColor = materialBaseColorFromMesh(mesh);
        materialTextureFromMesh(mesh);
        var mobShapeData = mobShape.MobShapeData.init(
            self.alloc,
            bgColor,
            zm.matToArr(localTransform),
        );
        try zmesh.io.appendMeshPrimitive(
            self.fileData,
            meshId,
            0, // gltf primitive index (submesh index)
            &mobShapeData.indices,
            &mobShapeData.positions,
            &mobShapeData.normals,
            &mobShapeData.textcoords,
            &mobShapeData.tangents,
        );
        try self.mob.addMeshData(meshId, mobShapeData);
    }

    pub fn transformFromNode(node: *gltf.Node, _: [*:0]const u8) zm.Mat {
        var nodeTransform = zm.identity();
        if (node.has_matrix == 1) {
            nodeTransform = zm.mul(nodeTransform, zm.matFromArr(node.matrix));
        }
        if (node.has_scale == 1) {
            const s = node.scale;
            const sm = zm.scaling(s[0], s[1], s[2]);
            nodeTransform = zm.mul(nodeTransform, sm);
        }
        if (node.has_rotation == 1) {
            const r = node.rotation;
            const quat: zm.Quat = .{ r[0], r[1], r[2], r[3] };
            nodeTransform = zm.mul(nodeTransform, zm.quatToMat(quat));
        }
        if (node.has_translation == 1) {
            const t = node.translation;
            const tm = zm.translation(t[0], t[1], t[2]);
            nodeTransform = zm.mul(nodeTransform, tm);
        }
        return nodeTransform;
    }

    pub fn materialBaseColorFromMesh(mesh: *gltf.Mesh) [4]gl.Float {
        const primitives = mesh.primitives;
        for (0..mesh.primitives_count) |i| {
            const primitive = primitives[i];
            const material: *gltf.Material = primitive.material orelse {
                continue;
            };
            if (material.has_pbr_metallic_roughness == 0) {
                continue;
            }
            const pbr: gltf.PbrMetallicRoughness = material.pbr_metallic_roughness;
            return pbr.base_color_factor;
        }
        return [_]gl.Float{ 1.0, 0.0, 1.0, 1.0 };
    }

    pub fn materialTextureFromMesh(mesh: *gltf.Mesh) void {
        const primitives = mesh.primitives;
        for (0..mesh.primitives_count) |i| {
            const primitive = primitives[i];
            const material: *gltf.Material = primitive.material orelse {
                continue;
            };
            const pbr: gltf.PbrMetallicRoughness = material.pbr_metallic_roughness;
            if (pbr.base_color_texture.texture) |_| {
                std.debug.print("has texture\n", .{});
            } else {
                std.debug.print("no texture\n", .{});
            }
            if (material.normal_texture.texture) |_| {
                std.debug.print("has normal_texture\n", .{});
            }
            if (material.occlusion_texture.texture) |_| {
                std.debug.print("has occlusion_texture\n", .{});
            }
            if (material.emissive_texture.texture) |_| {
                std.debug.print("has emissive_texture\n", .{});
            }
        }
    }

    pub fn draw(self: *MobMesh) !void {
        try self.mob.draw();
    }
};
