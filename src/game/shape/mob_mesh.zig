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

    pub fn textureInfo(self: *MobMesh, texture: gltf.Texture) !void {
        _ = self;
        const textureName = texture.name orelse {
            std.debug.print("no name for texture\n", .{});
            return;
        };
        std.debug.print("building texture: {s}\n", .{textureName});
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
            try self.buildNode(node, zm.identity());
        }
    }
    pub fn buildNode(self: *MobMesh, node: *gltf.Node, parentTransform: zm.Mat) !void {
        const nodeName = node.name orelse {
            std.debug.print("no name for node\n", .{});
            return;
        };
        const localTransform = zm.mul(parentTransform, transformFromNode(node, nodeName));
        std.debug.print("building node: {s}\n", .{nodeName});
        const mesh = node.mesh orelse {
            std.debug.print("{s} no mesh\n", .{nodeName});
            return;
        };
        try self.buildMesh(nodeName, localTransform, mesh);

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
            try self.buildNode(child, localTransform);
        }
    }

    pub fn buildMesh(self: *MobMesh, nodeName: [*:0]const u8, localTransform: zm.Mat, mesh: *gltf.Mesh) !void {
        const meshName = mesh.name orelse {
            std.debug.print("{s} mesh has no name\n", .{nodeName});
            return;
        };
        const meshId = self.meshMap.get(meshName) orelse {
            std.debug.print("{s}'s mesh {s} not found\n", .{ nodeName, meshName });
            return;
        };
        const bgColor = materialBaseColorFromMesh(mesh);
        std.debug.print("bg color: ({e}, {e}, {e}, {e})\n", .{ bgColor[0], bgColor[1], bgColor[2], bgColor[3] });
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

    fn printMatrix(m: zm.Mat) void {
        std.debug.print("\n\n\n\nmob_mesh:\n", .{});
        const r = zm.matToArr(m);
        for (0..r.len) |i| {
            const v = r[i];
            std.debug.print("{d} ", .{v});
            if (@mod(i + 1, 4) == 0) {
                std.debug.print("\n", .{});
            } else {
                std.debug.print(" ", .{});
            }
        }
        std.debug.print("\n", .{});
        for (0..r.len) |i| {
            const v = r[i];
            std.debug.print("{d} ", .{v});
        }
        std.debug.print("\n\n", .{});
        const t = zm.transpose(m);
        const r2 = zm.matToArr(t);
        for (0..r2.len) |i| {
            const v = r2[i];
            std.debug.print("{d} ", .{v});
            if (@mod(i + 1, 4) == 0) {
                std.debug.print("\n", .{});
            } else {
                std.debug.print(" ", .{});
            }
        }
        std.debug.print("\n", .{});
        for (0..r2.len) |i| {
            const v = r2[i];
            std.debug.print("{d} ", .{v});
        }
        std.debug.print("\n\n\n", .{});
    }

    pub fn transformFromNode(node: *gltf.Node, nodeName: [*:0]const u8) zm.Mat {
        var nodeTransform = zm.identity();
        if (node.has_matrix == 1) {
            std.debug.print("{s} node has matrix\n", .{nodeName});
            nodeTransform = zm.mul(nodeTransform, zm.matFromArr(node.matrix));
        }
        if (node.has_scale == 1) {
            std.debug.print("{s} node has scale\n", .{nodeName});
            const s = node.scale;
            const sm = zm.scaling(s[0], s[1], s[2]);
            nodeTransform = zm.mul(nodeTransform, sm);
        }
        if (node.has_rotation == 1) {
            std.debug.print("{s} node has rotation\n", .{nodeName});
            const r = node.rotation;
            const quat: zm.Quat = .{ r[0], r[1], r[2], r[3] };
            std.debug.print("rotation: {e} {e} {e}\n", .{ r[0], r[1], r[2] });
            nodeTransform = zm.mul(nodeTransform, zm.quatToMat(quat));
        }
        if (node.has_translation == 1) {
            std.debug.print("{s} node has translation\n", .{nodeName});
            const t = node.translation;
            const tm = zm.translation(t[0], t[1], t[2]);
            std.debug.print("translation: {e} {e} {e}\n", .{ t[0], t[1], t[2] });
            nodeTransform = zm.mul(nodeTransform, tm);
        }
        return nodeTransform;
    }

    pub fn materialBaseColorFromMesh(mesh: *gltf.Mesh) [4]gl.Float {
        const primitives = mesh.primitives;
        for (0..mesh.primitives_count) |i| {
            const primitive = primitives[i];
            const material: *gltf.Material = primitive.material orelse {
                std.debug.print("no material\n", .{});
                continue;
            };
            if (material.has_pbr_metallic_roughness == 0) {
                std.debug.print("no pbr_metallic_roughness\n", .{});
                continue;
            }
            const pbr: gltf.PbrMetallicRoughness = material.pbr_metallic_roughness;
            return pbr.base_color_factor;
        }
        return [_]gl.Float{0.0} ** 4;
    }

    pub fn draw(self: *MobMesh) !void {
        try self.mob.draw();
    }
};
