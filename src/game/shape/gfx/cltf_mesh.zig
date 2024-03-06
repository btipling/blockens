const std = @import("std");
const gl = @import("zopengl").bindings;
const zm = @import("zmath");
const zmesh = @import("zmesh");
const sampler = @import("./cltf_sampler.zig");
const game = @import("../../game.zig");
const data = @import("../../data/data.zig");
const game_state = @import("../../state/game.zig");
const gltf = zmesh.io.zcgltf;

pub const MeshErr = error{
    NoScenes,
    NoTexture,
    BuildErr,
};

pub const Mesh = struct {
    mob: *game_state.Mob,
    animation_map: std.AutoHashMap(usize, std.ArrayList(game_state.MobAnimation)),

    pub fn init(
        mob_id: i32,
    ) !Mesh {
        const file_data = try zmesh.io.parseAndLoadFile("./src/game/shape/mob/cgltf/char.glb");
        return .{
            .mob = game_state.Mob.init(game.state.allocator, mob_id, file_data),
            .animation_map = std.AutoHashMap(usize, std.ArrayList(game_state.MobAnimation)).init(
                game.state.allocator,
            ),
        };
    }

    pub fn deinit(self: *Mesh) void {
        self.animation_map.deinit();
    }

    pub fn meshIdForMesh(self: *Mesh, m: *gltf.Mesh) usize {
        for (0..self.mob.file_data.meshes_count) |i| {
            if (std.mem.eql(
                u8,
                std.mem.sliceTo(m.name.?, 0),
                std.mem.sliceTo(self.mob.file_data.meshes.?[i].name.?, 0),
            )) return i;
        }
        std.debug.print("pointer arithmatic is hard lol\n", .{});
        unreachable;
    }

    pub fn build(self: *Mesh) !void {
        const default_scene = self.mob.file_data.scene orelse {
            std.debug.print("no default scene\n", .{});
            return MeshErr.NoScenes;
        };
        try self.buildAnimations(self.mob.file_data.animations, self.mob.file_data.animations_count);
        try self.buildScene(default_scene);
        if (self.mob.file_data.cameras_count > 0) {
            if (self.mob.file_data.cameras) |c| {
                try self.addCamera(c[0]);
            }
        }
        try game.state.gfx.mob_data.put(self.mob.id, self.mob);
    }

    fn addCamera(_: *Mesh, camera: gltf.Camera) !void {
        const cameraName = camera.name orelse "::camera has no name::";
        std.debug.print("adding camera {s}", .{cameraName});
        switch (camera.type) {
            .perspective => {},
            else => return, // unsupported
        }
        const c_data = camera.data.perspective;
        var mc = game_state.MobCamera{
            .yfov = c_data.yfov,
            .znear = c_data.znear,
        };
        if (c_data.has_aspect_ratio != 0) {
            mc.aspectRatio = c_data.aspect_ratio;
        }
        if (c_data.has_zfar != 0) {
            mc.zfar = c_data.zfar;
        }
        // TODO actually add the camera
    }

    pub fn buildAnimations(self: *Mesh, animations: ?[*]gltf.Animation, animationCount: usize) !void {
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
                    continue;
                };
                if (node.mesh == null) {
                    continue;
                }
                const mesh_id = self.meshIdForMesh(node.mesh.?);
                var al = self.animation_map.get(mesh_id) orelse std.ArrayList(game_state.MobAnimation).init(
                    game.state.allocator,
                );
                var s = sampler.Sampler.init(
                    node,
                    animationName,
                    channel.target_path,
                    channel.sampler,
                );
                defer s.deinit();
                try s.build();
                if (s.frames) |frames| {
                    for (frames, 0..) |frame, ii| {
                        var ma: game_state.MobAnimation = .{
                            .frame = frame,
                        };
                        if (s.rotations) |rotations| {
                            ma.rotation = rotations[ii];
                        }
                        if (s.translations) |translations| {
                            ma.translation = translations[ii];
                        }
                        try al.append(ma);
                    }
                }
                try self.animation_map.put(mesh_id, al);
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
            try self.buildNode(node, null);
        }
    }

    pub fn buildNode(self: *Mesh, node: *gltf.Node, parent: ?usize) !void {
        const mesh = node.mesh orelse return;
        const mob_mesh: *game_state.MobMesh = try game.state.allocator.create(game_state.MobMesh);
        mob_mesh.* = .{
            .id = self.meshIdForMesh(mesh),
            .parent = parent,
            .color = materialBaseColorFromMesh(mesh),
            .texture = self.materialTextureFromMesh(mesh) catch null,
        };
        try self.mob.meshes.insert(mob_mesh.id, mob_mesh);
        try self.transformFromNode(node, mob_mesh);

        var nodes: [*]*gltf.Node = undefined;
        const T = @TypeOf(node.children);
        nodes = switch (T) {
            ?[*]*gltf.Node => node.children orelse return,
            else => return,
        };
        for (0..node.children_count) |i| {
            const child: *gltf.Node = nodes[i];
            try self.buildNode(child, mob_mesh.id);
        }
    }

    pub fn transformFromNode(_: *Mesh, node: *gltf.Node, mob_mesh: *game_state.MobMesh) !void {
        if (node.has_matrix == 1) {
            mob_mesh.transform = zm.matFromArr(node.matrix);
        }
        if (node.has_scale == 1) {
            const s = node.scale;
            mob_mesh.scale = .{ s[0], s[1], s[2], 0 };
        }
        if (node.has_rotation == 1) {
            mob_mesh.rotation = node.rotation;
        }
        if (node.has_translation == 1) {
            const t = node.translation;
            mob_mesh.translation = .{ t[0], t[1], t[2], 0 };
        }
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

    pub fn materialTextureFromMesh(_: *Mesh, mesh: *gltf.Mesh) ![]u8 {
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
                const bd = try game.state.allocator.alloc(u8, buffer.size);
                @memcpy(bd[0..buffer.size], bvd);
                return bd;
            }
        }
        return MeshErr.NoTexture;
    }
};
