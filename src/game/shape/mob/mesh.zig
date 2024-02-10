const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const shape = @import("shape.zig");
const view = @import("./view.zig");
const sampler = @import("./sampler.zig");
const state = @import("../../state/state.zig");
const data = @import("../../data/data.zig");
const gltf = zmesh.io.zcgltf;

pub const MeshErr = error{
    NoScenes,
    NoTexture,
    BuildErr,
};

pub const Mesh = struct {
    mobId: i32,
    mob: shape.Shape,
    meshMap: std.AutoHashMap(gltf.MutCString, u32),
    fileData: *gltf.Data, // managed by zmesh.io
    datas: std.ArrayList(shape.ShapeData),
    alloc: std.mem.Allocator,

    pub fn init(
        vm: view.View,
        mobId: i32,
        alloc: std.mem.Allocator,
    ) !Mesh {
        const vertexShaderSource = @embedFile("../../shaders/mob.vs");
        const fragmentShaderSource = @embedFile("../../shaders/mob.fs");
        const mob = try shape.Shape.init(
            vm,
            mobId,
            vertexShaderSource,
            fragmentShaderSource,
            alloc,
        );
        const fileData = try zmesh.io.parseAndLoadFile("./src/game/shape/mob/cgltf/char.glb");
        const datas = std.ArrayList(shape.ShapeData).init(alloc);

        return .{
            .mobId = mobId,
            .mob = mob,
            .meshMap = std.AutoHashMap(gltf.MutCString, u32).init(alloc),
            .fileData = fileData,
            .datas = datas,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: Mesh) void {
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

    pub fn mapMeshesByName(self: *Mesh) !void {
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

    pub fn build(self: *Mesh) !void {
        try self.mapMeshesByName();
        const defaultScene = self.fileData.scene orelse {
            std.debug.print("no default scene\n", .{});
            return MeshErr.NoScenes;
        };
        try self.buildScene(defaultScene);
        try self.buildAnimations(self.fileData.animations, self.fileData.animations_count);
    }

    pub fn buildAnimations(_: *Mesh, animations: ?[*]gltf.Animation, animationCount: usize) !void {
        if (animationCount == 0) {
            return;
        }
        if (animations == null) {
            return;
        }
        var ptr = animations.?;
        for (0..animationCount) |_| {
            const animation = ptr[0];
            const animationName = animation.name orelse "no animation name";
            for (0..animation.channels_count) |i| {
                const channel: gltf.AnimationChannel = animation.channels[i];
                const node = channel.target_node orelse {
                    std.debug.print("no node for {s}\n", .{animationName});
                    continue;
                };
                const aSampler = sampler.Sampler.init(
                    node,
                    animationName,
                    channel.target_path,
                    channel.sampler,
                );
                defer aSampler.deinit();
                var as = @constCast(&aSampler);
                try as.build();
            }
            ptr += 1;
        }
    }

    pub fn buildScene(self: *Mesh, scene: *gltf.Scene) !void {
        var nodes: [*]*gltf.Node = undefined;
        const T = @TypeOf(scene.nodes);
        nodes = switch (T) {
            ?[*]*gltf.Node => scene.nodes orelse return MeshErr.BuildErr,
            else => return MeshErr.BuildErr,
        };
        for (0..scene.nodes_count) |i| {
            const node: *gltf.Node = nodes[i];
            try self.buildNode(node, zm.identity());
        }
    }
    pub fn buildNode(self: *Mesh, node: *gltf.Node, parentTransform: zm.Mat) !void {
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

    pub fn buildMesh(self: *Mesh, nodeName: [*:0]const u8, localTransform: zm.Mat, mesh: *gltf.Mesh) !void {
        const meshName = mesh.name orelse {
            return;
        };
        const meshId = self.meshMap.get(meshName) orelse {
            std.debug.print("{s}'s mesh {s} not found\n", .{ nodeName, meshName });
            return;
        };
        const bgColor = materialBaseColorFromMesh(mesh);
        const td: ?[]u8 = self.materialTextureFromMesh(mesh) catch null;
        defer if (td) |_td| self.alloc.free(_td);
        var shapeData = shape.ShapeData.init(
            self.alloc,
            bgColor,
            zm.matToArr(localTransform),
            td,
        );
        try zmesh.io.appendMeshPrimitive(
            self.fileData,
            meshId,
            0, // gltf primitive index (submesh index)
            &shapeData.indices,
            &shapeData.positions,
            &shapeData.normals,
            &shapeData.textcoords,
            &shapeData.tangents,
        );
        try self.mob.addMeshData(meshId, shapeData);
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

    pub fn materialTextureFromMesh(self: *Mesh, mesh: *gltf.Mesh) ![]u8 {
        const primitives = mesh.primitives;
        for (0..mesh.primitives_count) |i| {
            const primitive = primitives[i];
            const material: *gltf.Material = primitive.material orelse {
                continue;
            };
            const pbr: gltf.PbrMetallicRoughness = material.pbr_metallic_roughness;
            if (pbr.base_color_texture.texture) |texture| {
                const image = texture.image orelse continue;
                const T = @TypeOf(image.buffer_view);
                const buffer = switch (T) {
                    ?*gltf.BufferView => image.buffer_view orelse continue,
                    else => continue,
                };
                const bvd = gltf.BufferView.data(buffer.*) orelse continue;
                const bd = try self.alloc.alloc(u8, buffer.size);
                @memcpy(bd[0..buffer.size], bvd);
                return bd;
            }
        }
        return MeshErr.NoTexture;
    }

    pub fn draw(self: *Mesh) !void {
        try self.mob.draw();
    }
};
