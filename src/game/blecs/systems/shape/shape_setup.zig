const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const config = @import("config");
const tags = @import("../../tags.zig");
const game = @import("../../../game.zig");
const chunk = @import("../../../chunk.zig");
const game_state = @import("../../../state.zig");
const game_mob = @import("../../../mob.zig");
const math = @import("../../../math/math.zig");
const gfx = @import("../../../gfx/gfx.zig");
const components = @import("../../components/components.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "ShapeSetupSystem", ecs.PreStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.shape.Shape) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.shape.NeedsSetup) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const sh: []components.shape.Shape = ecs.field(it, components.shape.Shape, 1) orelse continue;
            if (config.use_tracy) {
                const tracy_zone = ztracy.ZoneNC(@src(), "ShapeSetupSystem", 0xff_00_ff_f0);
                defer tracy_zone.End();
                shapeSetup(world, entity, sh[i]);
            } else {
                shapeSetup(world, entity, sh[i]);
            }
        }
    }
}

fn shapeSetup(world: *ecs.world_t, entity: ecs.entity_t, sh: components.shape.Shape) void {
    var e = extractions.extract(world, entity) catch @panic("nope");
    defer e.deinit();

    const mesh_data: gfx.mesh.meshData = switch (sh.shape_type) {
        .plane => gfx.mesh.plane(),
        .cube => gfx.mesh.cube(),
        .meshed_voxel => blk: {
            const data: *const components.block.BlockData = ecs.get(world, entity, components.block.BlockData) orelse @panic("nope");
            var c: *chunk.Chunk = undefined;
            if (data.is_settings) {
                c = game.state.gfx.settings_chunks.get(data.chunk_world_position).?;
            } else {
                c = game.state.gfx.game_chunks.get(data.chunk_world_position).?;
            }
            break :blk c.elements.items[data.element_index].mesh_data.toMeshData();
        },
        .multidraw_voxel => gfx.mesh.cube(), // just to setup the positions
        .mob => gfx.mesh.mob(world, entity),
        .bounding_box => gfx.mesh.bounding_box(e.mob_id), // just to setup the positions
        .block_highlight => gfx.mesh.block_highlight(),
    };

    var erc: *game_state.ElementsRendererConfig = game.state.allocator.create(game_state.ElementsRendererConfig) catch @panic("nope");
    var dc: ?struct { usize, usize } = null;
    if (e.has_demo_cube_texture) {
        dc = struct { usize, usize }{ e.dc_t_beg, e.dc_t_end };
    }
    erc.* = .{
        .vertexShader = shaders.genVertexShader(&e, &mesh_data),
        .fragmentShader = shaders.genFragmentShader(&e, &mesh_data),
        .mesh_data = mesh_data,
        .transform = null,
        .ubo_binding_point = null,
        .demo_cube_texture = dc,
        .keyframes = e.keyframes,
        .animation_binding_point = e.animation_binding_point,
        .is_instanced = e.is_instanced,
        .block_id = e.block_id,
        .has_mob_texture = e.has_mob_texture,
        .has_block_texture_atlas = e.has_texture_atlas,
        .is_multi_draw = e.is_multi_draw,
        .has_attr_translation = e.is_multi_draw,
    };
    const erc_id = ecs.new_id(world);
    game.state.gfx.renderConfigs.put(erc_id, erc) catch unreachable;
    if (e.has_uniform_mat) erc.transform = e.uniform_mat;
    if (e.has_ubo) erc.ubo_binding_point = e.ubo_binding_point;
    _ = ecs.set(world, entity, components.gfx.ElementsRendererConfig, .{ .id = erc_id });
    ecs.remove(world, entity, components.shape.NeedsSetup);
}

const shaders = struct {
    fn genVertexShader(e: *const extractions, mesh_data: *const gfx.mesh.meshData) [:0]const u8 {
        const v_cfg = gfx.shadergen.vertex.VertexShaderGen.vertexShaderConfig{
            .debug = e.debug,
            .has_uniform_mat = e.has_uniform_mat,
            .has_ubo = e.has_ubo,
            .scale = e.scale,
            .rotation = e.rotation,
            .translation = e.translation,
            .has_texture_coords = mesh_data.texcoords != null,
            .has_normals = mesh_data.normals != null,
            .has_edges = e.outline_color != null,
            .animation_block_index = e.animation_binding_point,
            .animation_id = e.animation_id,
            .is_instanced = e.is_instanced,
            .is_multi_draw = e.is_multi_draw,
            .is_meshed = e.is_meshed,
            .has_block_data = e.has_texture_atlas,
            .has_attr_translation = e.is_multi_draw,
            .mesh_transforms = blk: {
                if (e.mesh_transforms) |mt| break :blk mt.items;
                break :blk null;
            },
            .num_animation_frames = blk: {
                if (e.keyframes) |akf| break :blk @intCast(akf.len);
                break :blk 0;
            },
        };
        return gfx.shadergen.vertex.VertexShaderGen.genVertexShader(v_cfg) catch unreachable;
    }
    fn genFragmentShader(e: *const extractions, mesh_data: *const gfx.mesh.meshData) [:0]const u8 {
        var has_texture = false;
        if (mesh_data.texcoords != null) {
            if (e.block_id != null) has_texture = true;
            if (e.has_demo_cube_texture) has_texture = true;
            if (e.has_texture_atlas) has_texture = true;
            if (e.has_mob_texture) has_texture = true;
        }
        var block_index: usize = 0;
        if (e.block_id) |bi| {
            block_index = game.state.ui.data.texture_atlas_block_index[@intCast(bi)];
        }
        const f_cfg = gfx.shadergen.fragment.FragmentShaderGen.fragmentShaderConfig{
            .debug = e.debug,
            .color = e.color,
            .has_texture_coords = mesh_data.texcoords != null,
            .has_texture = has_texture,
            .has_normals = mesh_data.normals != null,
            .is_meshed = e.is_meshed,
            .has_block_data = e.has_texture_atlas,
            .outline_color = e.outline_color,
        };
        return gfx.shadergen.fragment.FragmentShaderGen.genFragmentShader(f_cfg) catch unreachable;
    }
};

const extractions = struct {
    rotation: ?@Vector(4, f32) = null,
    scale: ?@Vector(4, f32) = null,
    translation: ?@Vector(4, f32) = null,
    color: ?@Vector(4, f32) = null,
    outline_color: ?@Vector(4, f32) = null,
    debug: bool = false,
    has_ubo: bool = false,
    ubo_binding_point: u32 = 0,
    has_uniform_mat: bool = false,
    uniform_mat: zm.Mat = zm.identity(),
    has_demo_cube_texture: bool = false,
    has_texture_atlas: bool = false,
    dc_t_beg: usize = 0,
    dc_t_end: usize = 0,
    has_animation_block: bool = false,
    animation_binding_point: ?u32 = null,
    animation_id: ?u32 = null,
    keyframes: ?[]game_state.ElementsRendererConfig.AnimationKeyFrame = null,
    is_instanced: bool = false,
    block_id: ?u8 = null,
    is_meshed: bool = false,
    has_mob_texture: bool = false,
    mesh_transforms: ?std.ArrayList(gfx.shadergen.vertex.MeshTransforms) = null,
    is_multi_draw: bool = false,
    mob_id: i32 = 0,

    fn deinit(self: *extractions) void {
        if (self.mesh_transforms) |mt| mt.deinit();
    }

    fn extractMultiDraw(e: *extractions, world: *ecs.world_t, entity: ecs.entity_t) void {
        if (ecs.has_id(world, entity, ecs.id(components.block.UseMultiDraw))) {
            e.is_multi_draw = true;
            e.is_meshed = true;
        }
    }

    fn extractBoundingBox(e: *extractions, world: *ecs.world_t, entity: ecs.entity_t) void {
        if (!ecs.has_id(world, entity, ecs.id(components.mob.BoundingBox))) return;
        if (ecs.get_id(world, entity, ecs.id(components.mob.BoundingBox))) |opaque_ptr| {
            const bb: *const components.mob.BoundingBox = @ptrCast(@alignCast(opaque_ptr));
            e.mob_id = bb.mob_id;
        }
    }

    fn extractOutline(e: *extractions, world: *ecs.world_t, entity: ecs.entity_t) void {
        if (!ecs.has_id(world, entity, ecs.id(components.shape.Outline))) return;
        if (ecs.get_id(world, entity, ecs.id(components.shape.Outline))) |opaque_ptr| {
            const ol: *const components.shape.Outline = @ptrCast(@alignCast(opaque_ptr));
            e.outline_color = ol.color;
        }
    }

    fn extractBlock(e: *extractions, world: *ecs.world_t, entity: ecs.entity_t) void {
        if (ecs.get_id(world, entity, ecs.id(components.block.Block))) |opaque_ptr| {
            const b: *const components.block.Block = @ptrCast(@alignCast(opaque_ptr));
            if (e.debug) std.debug.print("extractBlock: has block\n", .{});
            e.block_id = b.block_id;
            if (ecs.has_id(world, entity, ecs.id(components.block.Instance))) {
                if (e.debug) std.debug.print("extractBlock: has instances\n", .{});
                e.is_instanced = true;
            }
            if (ecs.has_id(world, entity, ecs.id(components.block.BlockData))) {
                if (e.debug) std.debug.print("extractBlock: is meshed\n", .{});
                e.is_meshed = true;
            }
        }
    }

    fn extractMesh(e: *extractions, world: *ecs.world_t, entity: ecs.entity_t) !void {
        if (!ecs.has_id(world, entity, ecs.id(components.mob.Mesh))) return;
        const mesh_c: *const components.mob.Mesh = ecs.get(world, entity, components.mob.Mesh).?;
        if (!ecs.has_id(world, mesh_c.mob_entity, ecs.id(components.mob.Mob))) return;
        const mob_c: *const components.mob.Mob = ecs.get(world, mesh_c.mob_entity, components.mob.Mob).?;
        if (!game.state.gfx.mob_data.contains(mob_c.mob_id)) return;
        const mob_data: *game_mob.Mob = game.state.gfx.mob_data.get(mob_c.mob_id).?;
        if (mob_data.meshes.items.len <= mesh_c.mesh_id) return;
        const mesh: *game_mob.MobMesh = mob_data.meshes.items[mesh_c.mesh_id];
        e.has_mob_texture = mesh.texture != null;
        e.color = mesh.color;
        e.mob_id = mob_c.mob_id;
        var cm = mesh;
        while (true) {
            if (e.mesh_transforms == null) {
                e.mesh_transforms = std.ArrayList(gfx.shadergen.vertex.MeshTransforms).init(game.state.allocator);
            }
            try e.mesh_transforms.?.append(.{
                .scale = cm.scale,
                .rotation = cm.rotation,
                .translation = cm.translation,
            });
            if (cm.parent == null) break;
            cm = mob_data.meshes.items[cm.parent.?];
        }

        extractMeshAnimation(e, world, entity, mesh);
    }

    fn extractMeshAnimation(
        e: *extractions,
        world: *ecs.world_t,
        entity: ecs.entity_t,
        cm: *game_mob.MobMesh,
    ) void {
        if (!ecs.has_id(world, entity, ecs.id(components.gfx.AnimationSSBO))) {
            return;
        }
        if (cm.animations == null or cm.animations.?.items.len < 1) {
            return;
        }
        var ssbo: u32 = 0;
        var animation_id: u32 = 0;
        if (ecs.get_id(world, entity, ecs.id(components.gfx.AnimationSSBO))) |opaque_ptr| {
            const a: *const components.gfx.AnimationSSBO = @ptrCast(@alignCast(opaque_ptr));
            ssbo = a.ssbo;
            animation_id = a.animation_id;
        }
        var ar = std.ArrayListUnmanaged(
            game_state.ElementsRendererConfig.AnimationKeyFrame,
        ){};
        defer ar.deinit(game.state.allocator);
        for (0..cm.animations.?.items.len) |i| {
            const akf = cm.animations.?.items[i];
            ar.append(
                game.state.allocator,
                game_state.ElementsRendererConfig.AnimationKeyFrame{
                    .frame = akf.frame,
                    .scale = akf.scale orelse @Vector(4, f32){ 1, 1, 1, 1 },
                    .rotation = akf.rotation orelse @Vector(4, f32){ 0, 0, 0, 1 },
                    .translation = akf.translation orelse @Vector(4, f32){ 0, 0, 0, 0 },
                },
            ) catch unreachable;
        }
        if (ar.items.len > 0) {
            e.animation_binding_point = ssbo;
            e.animation_id = animation_id;
            e.has_animation_block = true;
            e.keyframes = ar.toOwnedSlice(game.state.allocator) catch unreachable;
        }
    }

    fn extractAnimation(e: *extractions, world: *ecs.world_t, entity: ecs.entity_t) void {
        var it = ecs.children(world, entity);
        while (ecs.children_next(&it)) {
            for (0..it.count()) |i| {
                const child_entity = it.entities()[i];
                if (!ecs.has_id(world, child_entity, ecs.id(components.gfx.AnimationSSBO))) {
                    continue;
                }
                var ar = std.ArrayListUnmanaged(
                    game_state.ElementsRendererConfig.AnimationKeyFrame,
                ){};
                var ssbo: u32 = 0;
                if (ecs.get_id(world, child_entity, ecs.id(components.gfx.AnimationSSBO))) |opaque_ptr| {
                    const a: *const components.gfx.AnimationSSBO = @ptrCast(@alignCast(opaque_ptr));
                    ssbo = a.ssbo;
                }
                defer ar.deinit(game.state.allocator);
                var cit = ecs.children(world, child_entity);
                while (ecs.children_next(&cit)) {
                    for (0..cit.count()) |ii| {
                        const subchild_entity = cit.entities()[ii];
                        if (ecs.has_id(world, subchild_entity, ecs.id(components.gfx.AnimationKeyFrame))) {
                            if (ecs.get_id(world, subchild_entity, ecs.id(components.gfx.AnimationKeyFrame))) |opaque_ptr| {
                                const akf: *const components.gfx.AnimationKeyFrame = @ptrCast(@alignCast(opaque_ptr));
                                ar.append(
                                    game.state.allocator,
                                    game_state.ElementsRendererConfig.AnimationKeyFrame{
                                        .frame = akf.frame,
                                        .scale = akf.scale,
                                        .rotation = akf.rotation,
                                        .translation = akf.translation,
                                    },
                                ) catch unreachable;
                            }
                        }
                    }
                }
                if (ar.items.len > 0) {
                    e.animation_binding_point = ssbo;
                    e.has_animation_block = true;
                    e.keyframes = ar.toOwnedSlice(game.state.allocator) catch unreachable;
                }
            }
        }
    }

    fn extract(world: *ecs.world_t, entity: ecs.entity_t) !extractions {
        var e = extractions{};
        if (ecs.has_id(world, entity, ecs.id(components.Debug))) {
            e.debug = true;
        }
        extractBlock(&e, world, entity);
        if (ecs.get_id(world, entity, ecs.id(components.shape.Rotation))) |opaque_ptr| {
            const r: *const components.shape.Rotation = @ptrCast(@alignCast(opaque_ptr));
            e.rotation = r.rot;
        }
        if (ecs.get_id(world, entity, ecs.id(components.shape.Scale))) |opaque_ptr| {
            const r: *const components.shape.Rotation = @ptrCast(@alignCast(opaque_ptr));
            e.scale = r.rot;
        }
        if (ecs.get_id(world, entity, ecs.id(components.shape.Translation))) |opaque_ptr| {
            const t: *const components.shape.Translation = @ptrCast(@alignCast(opaque_ptr));
            e.translation = t.translation;
        }
        if (ecs.get_id(world, entity, ecs.id(components.shape.Color))) |opaque_ptr| {
            const c: *const components.shape.Color = @ptrCast(@alignCast(opaque_ptr));
            e.color = c.color;
        }
        if (ecs.get_id(world, entity, ecs.id(components.shape.DemoCubeTexture))) |opaque_ptr| {
            const dct: *const components.shape.DemoCubeTexture = @ptrCast(@alignCast(opaque_ptr));
            e.has_demo_cube_texture = true;
            e.dc_t_beg = dct.beg;
            e.dc_t_end = dct.end;
        }
        if (ecs.has_id(world, entity, ecs.id(components.block.UseTextureAtlas))) {
            e.has_texture_atlas = true;
        }
        if (ecs.get_id(world, entity, ecs.id(components.shape.UBO))) |opaque_ptr| {
            const u: *const components.shape.UBO = @ptrCast(@alignCast(opaque_ptr));
            e.has_ubo = true;
            e.ubo_binding_point = u.binding_point;
        }
        if (ecs.get_id(world, entity, ecs.id(components.screen.WorldRotation))) |opaque_ptr| {
            const u: *const components.screen.WorldRotation = @ptrCast(@alignCast(opaque_ptr));
            e.has_uniform_mat = true;
            e.uniform_mat = zm.mul(e.uniform_mat, zm.quatToMat(u.rotation));
        }
        if (ecs.get_id(world, entity, ecs.id(components.screen.WorldLocation))) |opaque_ptr| {
            const u: *const components.screen.WorldLocation = @ptrCast(@alignCast(opaque_ptr));
            e.has_uniform_mat = true;
            e.uniform_mat = zm.mul(e.uniform_mat, zm.translationV(u.loc));
        }
        try extractMesh(&e, world, entity);
        extractAnimation(&e, world, entity);
        extractMultiDraw(&e, world, entity);
        extractBoundingBox(&e, world, entity);
        extractOutline(&e, world, entity);
        return e;
    }
};
