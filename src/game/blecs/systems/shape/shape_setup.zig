const system_name = "ShapeSetupSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.PreStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.shape.Shape) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.shape.NeedsSetup) };
    desc.run = if (config.use_tracy) runWithTrace else run;
    return desc;
}

fn runWithTrace(it: *ecs.iter_t) callconv(.C) void {
    ztracy.Message(system_name);
    const tracy_zone = ztracy.ZoneNC(@src(), system_name, 0xff_00_ff_f0);
    defer tracy_zone.End();
    return run(it);
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const sh: []components.shape.Shape = ecs.field(it, components.shape.Shape, 1) orelse continue;
            shapeSetup(world, entity, sh[i]);
        }
    }
}

fn shapeSetup(world: *ecs.world_t, entity: ecs.entity_t, sh: components.shape.Shape) void {
    var e = extractions.extract(world, entity) catch @panic("nope");
    defer e.deinit();

    const mesh_data: gfx.mesh.meshData = switch (sh.shape_type) {
        .plane => gfx.mesh.plane(),
        .cube => gfx.mesh.cube(),
        .multidraw_voxel => gfx.mesh.cube(),
        .sub_chunks => gfx.mesh.subchunk(),
        .mob => gfx.mesh.mob(world, entity),
        .bounding_box => gfx.mesh.bounding_box(e.mob_id),
        .block_highlight => gfx.mesh.block_highlight(),
    };

    var erc: *gfx.ElementsRendererConfig = game.state.allocator.create(gfx.ElementsRendererConfig) catch @panic("nope");
    var dc: ?struct { usize, usize } = null;
    if (e.has_demo_cube_texture) {
        dc = struct { usize, usize }{ e.dc_t_beg, e.dc_t_end };
    }
    erc.* = .{
        .mesh_data = mesh_data,
        .transform = null,
        .ubo_binding_point = null,
        .demo_cube_texture = dc,
        .block_id = e.block_id,
        .has_mob_texture = e.has_mob_texture,
        .has_block_texture_atlas = e.has_texture_atlas,
        .is_multi_draw = e.is_multi_draw,
        .has_attr_translation = e.is_multi_draw,
        .is_sub_chunks = e.is_sub_chunks,
    };
    if (!e.is_multi_draw or !gfx.gl.Gl.hasMultiDrawShaders()) {
        erc.vertexShader = shaders.genVertexShader(&e, &mesh_data);
        erc.fragmentShader = shaders.genFragmentShader(&e, &mesh_data);
    }
    const erc_id = ecs.new_id(world);
    game.state.gfx.renderConfigs.put(erc_id, erc) catch @panic("OOM");
    if (e.has_uniform_mat) erc.transform = e.uniform_mat;
    if (e.has_ubo) erc.ubo_binding_point = e.ubo_binding_point;
    _ = ecs.set(world, entity, components.gfx.ElementsRendererConfig, .{ .id = erc_id });
    ecs.remove(world, entity, components.shape.NeedsSetup);
}

const shaders = struct {
    fn genVertexShader(e: *const extractions, mesh_data: *const gfx.mesh.meshData) [:0]const u8 {
        var animation_block_index: ?u32 = null;
        if (e.animation != null) {
            animation_block_index = game.state.gfx.animation_data.animation_binding_point;
        }
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
            .animation_block_index = animation_block_index,
            .animation = e.animation,
            .is_multi_draw = e.is_multi_draw,
            .is_meshed = e.is_meshed,
            .has_block_data = e.has_texture_atlas,
            .has_attr_translation = e.is_multi_draw,
            .mesh_transforms = blk: {
                if (e.mesh_transforms) |mt| break :blk mt.items;
                break :blk null;
            },
            .is_sub_chunks = e.is_sub_chunks,
        };
        return gfx.shadergen.vertex.VertexShaderGen.genVertexShader(v_cfg) catch @panic("vertex shader gen fail");
    }
    fn genFragmentShader(e: *const extractions, mesh_data: *const gfx.mesh.meshData) [:0]const u8 {
        const has_normals = mesh_data.normals != null;
        var has_texture = false;
        if (mesh_data.texcoords != null) {
            if (e.block_id != null) has_texture = true;
            if (e.has_demo_cube_texture) has_texture = true;
            if (e.has_texture_atlas) has_texture = true;
            if (e.has_mob_texture) has_texture = true;
        } else if (e.has_texture_atlas and e.lighting_block_index != null) has_texture = true;
        var block_index: usize = 0;
        if (e.block_id) |bi| {
            block_index = game.state.ui.texture_atlas_block_index[@intCast(bi)];
        }
        const f_cfg = gfx.shadergen.fragment.FragmentShaderGen.fragmentShaderConfig{
            .debug = e.debug,
            .color = e.color,
            .has_texture_coords = mesh_data.texcoords != null,
            .has_texture = has_texture,
            .has_normals = has_normals,
            .is_meshed = e.is_meshed,
            .has_block_data = e.has_texture_atlas,
            .outline_color = e.outline_color,
            .lighting_block_index = if (has_texture) e.lighting_block_index else null,
        };
        return gfx.shadergen.fragment.FragmentShaderGen.genFragmentShader(f_cfg) catch @panic("frag shader gen fail");
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
    animation: ?*gfx.Animation = null,
    block_id: ?u8 = null,
    is_meshed: bool = false,
    has_mob_texture: bool = false,
    lighting_block_index: ?u32 = null,
    mesh_transforms: ?std.ArrayList(gfx.shadergen.vertex.MeshTransforms) = null,
    is_multi_draw: bool = false,
    mob_id: i32 = 0,
    is_sub_chunks: bool = false,

    fn deinit(self: *extractions) void {
        if (self.mesh_transforms) |mt| mt.deinit();
    }

    fn extractMultiDraw(e: *extractions, world: *ecs.world_t, entity: ecs.entity_t) void {
        if (ecs.has_id(world, entity, ecs.id(components.block.UseMultiDraw))) {
            e.is_multi_draw = true;
            e.is_meshed = true;
        }
    }

    fn extractLighting(e: *extractions, world: *ecs.world_t, entity: ecs.entity_t) void {
        if (ecs.get(world, entity, components.shape.Lighting)) |l| {
            e.lighting_block_index = l.ssbo;
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
            if (ecs.has_id(world, entity, ecs.id(components.block.BlockData))) {
                if (e.debug) std.debug.print("extractBlock: is meshed\n", .{});
                e.is_meshed = true;
            }
        }
    }

    fn extractSubChunks(e: *extractions, world: *ecs.world_t, entity: ecs.entity_t) void {
        if (ecs.has_id(world, entity, ecs.id(components.block.SubChunks))) {
            if (e.debug) std.debug.print("extractBlock: is meshed\n", .{});
            e.is_sub_chunks = true;
            e.is_meshed = true;
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
        if (!ecs.has_id(world, entity, ecs.id(components.gfx.AnimationMesh))) {
            return;
        }
        if (cm.animations == null or cm.animations.?.items.len < 1) {
            return;
        }
        const a: *const components.gfx.AnimationMesh = ecs.get(
            world,
            entity,
            components.gfx.AnimationMesh,
        ) orelse return;
        const akr: gfx.AnimationData.AnimationRefKey = .{
            .animation_id = a.animation_id,
            .animation_mesh_id = a.mesh_id,
        };

        // Check if we already have the animation:
        if (game.state.gfx.animation_data.data.get(akr)) |ad| {
            e.animation = ad;
            return;
        }

        // Add new animation:
        var ar = std.ArrayListUnmanaged(
            gfx.Animation.AnimationKeyFrame,
        ){};
        defer ar.deinit(game.state.allocator);
        for (0..cm.animations.?.items.len) |i| {
            const akf = cm.animations.?.items[i];
            ar.append(
                game.state.allocator,
                gfx.Animation.AnimationKeyFrame{
                    .frame = akf.frame,
                    .scale = akf.scale orelse @Vector(4, f32){ 1, 1, 1, 1 },
                    .rotation = akf.rotation orelse @Vector(4, f32){ 0, 0, 0, 1 },
                    .translation = akf.translation orelse @Vector(4, f32){ 0, 0, 0, 0 },
                },
            ) catch @panic("OOM");
        }
        if (ar.items.len < 1) return;
        const animation: *gfx.Animation = game.state.allocator.create(gfx.Animation) catch @panic("OOM");
        animation.* = .{
            .animation_id = akr.animation_id,
            .keyframes = ar.toOwnedSlice(game.state.allocator) catch @panic("OOM"),
        };
        game.state.gfx.addAnimation(akr, animation);
        e.animation = animation;
    }

    fn extractAnimation(e: *extractions, world: *ecs.world_t, entity: ecs.entity_t) void {
        var it = ecs.children(world, entity);
        while (ecs.children_next(&it)) {
            for (0..it.count()) |i| {
                const child_entity = it.entities()[i];

                const a: *const components.gfx.AnimationMesh = ecs.get(
                    world,
                    child_entity,
                    components.gfx.AnimationMesh,
                ) orelse continue;

                const akr: gfx.AnimationData.AnimationRefKey = .{
                    .animation_id = a.animation_id,
                    .animation_mesh_id = a.mesh_id,
                };

                if (game.state.gfx.animation_data.data.get(akr)) |ad| {
                    e.animation = ad;
                    continue;
                }
                var ar = std.ArrayListUnmanaged(
                    gfx.Animation.AnimationKeyFrame,
                ){};
                defer ar.deinit(game.state.allocator);
                var cit = ecs.children(world, child_entity);
                while (ecs.children_next(&cit)) {
                    for (0..cit.count()) |ii| {
                        const subchild_entity = cit.entities()[ii];
                        if (ecs.get(world, subchild_entity, components.gfx.AnimationKeyFrame)) |akf| {
                            ar.append(
                                game.state.allocator,
                                gfx.Animation.AnimationKeyFrame{
                                    .frame = akf.frame,
                                    .scale = akf.scale,
                                    .rotation = akf.rotation,
                                    .translation = akf.translation,
                                },
                            ) catch @panic("OOM");
                        }
                    }
                }
                if (ar.items.len < 1) continue;
                const animation: *gfx.Animation = game.state.allocator.create(gfx.Animation) catch @panic("OOM");
                animation.* = .{
                    .animation_id = akr.animation_id,
                    .keyframes = ar.toOwnedSlice(game.state.allocator) catch @panic("OOM"),
                };
                game.state.gfx.addAnimation(akr, animation);
                e.animation = animation;
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
        extractLighting(&e, world, entity);
        extractSubChunks(&e, world, entity);
        return e;
    }
};

const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const config = @import("config");
const tags = @import("../../tags.zig");
const game = @import("../../../game.zig");
const game_mob = @import("../../../mob.zig");
const math = @import("../../../math/math.zig");
const gfx = @import("../../../gfx/gfx.zig");
const components = @import("../../components/components.zig");
const block = @import("../../../block/block.zig");
const chunk = block.chunk;
