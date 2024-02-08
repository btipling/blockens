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
    NoTexture,
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
        try self.mapMeshesByName();
        const defaultScene = self.fileData.scene orelse {
            std.debug.print("no default scene\n", .{});
            return MobMeshErr.NoScenes;
        };
        try self.buildScene(defaultScene);
        try self.buildAnimations(self.fileData.animations, self.fileData.animations_count);
    }

    pub fn buildAnimations(_: *MobMesh, animations: ?[*]gltf.Animation, animationCount: usize) !void {
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
            std.debug.print("\n\nFound animation {s} with {d} animation channels and {d} samplers \n", .{
                animationName,
                animation.channels_count,
                animation.samplers_count,
            });
            for (0..animation.channels_count) |i| {
                const channel: gltf.AnimationChannel = animation.channels[i];
                switch (channel.target_path) {
                    .translation => std.debug.print("found translation animation for {s}\n", .{animationName}),
                    .rotation => std.debug.print("found rotation animation for {s}\n", .{animationName}),
                    .scale => std.debug.print("found scale animation for {s}\n", .{animationName}),
                    .weights => std.debug.print("found weights animation for {s}\n", .{animationName}),
                    else => std.debug.print("found invalid animation for {s}\n", .{animationName}),
                }
                const node = channel.target_node orelse {
                    std.debug.print("no node for {s}\n", .{animationName});
                    continue;
                };
                const nodeName = node.name orelse "no node name";
                std.debug.print("animation {s} is for node {s}\n", .{ animationName, nodeName });
                const sampler = channel.sampler;
                switch (sampler.interpolation) {
                    .linear => std.debug.print("found linear interpolation for {s}\n", .{animationName}),
                    .step => std.debug.print("found step interpolation for {s}\n", .{animationName}),
                    .cubic_spline => std.debug.print("found cubic spline interpolation for {s}\n", .{animationName}),
                }
                const input = sampler.input;
                printAccessor(input);
                const output = sampler.output;
                printAccessor(output);
            }
            ptr += 1;
            std.debug.print("\n\n", .{});
        }
    }

    pub fn printAccessor(acessor: *gltf.Accessor) void {
        const accessorName = acessor.name orelse "no accessor name";
        std.debug.print("accessor {s} has {d} elements, and {d} byte offset with stride of {d}\n", .{
            accessorName,
            acessor.count,
            acessor.offset,
            acessor.stride,
        });
        switch (acessor.component_type) {
            .r_8 => std.debug.print("accessor {s} has r_8 component type\n", .{accessorName}),
            .r_8u => std.debug.print("accessor {s} has r_8u component type\n", .{accessorName}),
            .r_16 => std.debug.print("accessor {s} has r_16 component type\n", .{accessorName}),
            .r_16u => std.debug.print("accessor {s} has r_16u component type\n", .{accessorName}),
            .r_32u => std.debug.print("accessor {s} has r_32u component type\n", .{accessorName}),
            .r_32f => std.debug.print("accessor {s} has r_32f component type\n", .{accessorName}),
            else => std.debug.print("accessor {s} has invalid component type\n", .{accessorName}),
        }
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
        const td: ?[]u8 = self.materialTextureFromMesh(mesh) catch null;
        defer if (td) |_td| self.alloc.free(_td);
        var mobShapeData = mobShape.MobShapeData.init(
            self.alloc,
            bgColor,
            zm.matToArr(localTransform),
            td,
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

    pub fn materialTextureFromMesh(self: *MobMesh, mesh: *gltf.Mesh) ![]u8 {
        const primitives = mesh.primitives;
        for (0..mesh.primitives_count) |i| {
            const primitive = primitives[i];
            const material: *gltf.Material = primitive.material orelse {
                continue;
            };
            const pbr: gltf.PbrMetallicRoughness = material.pbr_metallic_roughness;
            if (pbr.base_color_texture.texture) |texture| {
                std.debug.print("has texture\n", .{});
                const image = texture.image orelse continue;
                const mime_type = image.mime_type orelse "no_mime_type";
                std.debug.print("image mime type: {s}\n", .{mime_type});
                const T = @TypeOf(image.buffer_view);
                const buffer = switch (T) {
                    ?*gltf.BufferView => image.buffer_view orelse continue,
                    else => continue,
                };
                const bvd = gltf.BufferView.data(buffer.*) orelse continue;
                const bd = try self.alloc.alloc(u8, buffer.size);
                @memcpy(bd[0..buffer.size], bvd);
                return bd;
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
        return MobMeshErr.NoTexture;
    }

    pub fn draw(self: *MobMesh) !void {
        try self.mob.draw();
    }
};
