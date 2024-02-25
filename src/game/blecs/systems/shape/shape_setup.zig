const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl").bindings;
const zmesh = @import("zmesh");
const zm = @import("zmath");
const tags = @import("../../tags.zig");
const game = @import("../../../game.zig");
const game_state = @import("../../../state/game.zig");
const math = @import("../../../math/math.zig");
const gfx = @import("../../../shape/gfx/gfx.zig");
const components = @import("../../components/components.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "ShapeSetupSystem", ecs.OnUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.shape.Shape) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.shape.NeedsSetup) };
    desc.run = run;
    return desc;
}

const meshData = struct {
    positions: [][3]gl.Float,
    indices: []gl.Uint,
    texcoords: ?[][2]gl.Float = null,
    normals: ?[][3]gl.Float = null,
};

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const sh: []components.shape.Shape = ecs.field(it, components.shape.Shape, 1) orelse return;
            const mesh_data = switch (sh[i].shape_type) {
                .plane => plane(),
                else => cube(),
            };

            const e = extractions.extract(world, entity);
            var erc: *game_state.ElementsRendererConfig = game.state.allocator.create(game_state.ElementsRendererConfig) catch unreachable;
            var dc: ?struct { usize, usize } = null;
            if (e.has_demo_cube_texture) {
                dc = struct { usize, usize }{ e.dc_t_beg, e.dc_t_end };
            }
            erc.* = .{
                .vertexShader = shaders.genVertexShader(&e, &mesh_data),
                .fragmentShader = shaders.genFragmentShader(&e, &mesh_data),
                .positions = mesh_data.positions,
                .indices = mesh_data.indices,
                .transform = null,
                .ubo_binding_point = null,
                .demo_cube_texture = dc,
                .texcoords = mesh_data.texcoords,
                .normals = mesh_data.normals,
                .keyframes = e.keyframes,
                .animation_binding_point = e.animation_binding_point,
            };
            const erc_id = ecs.new_id(world);
            game.state.gfx.renderConfigs.put(erc_id, erc) catch unreachable;
            if (e.has_uniform_mat) erc.transform = e.uniform_mat;
            if (e.has_ubo) erc.ubo_binding_point = e.ubo_binding_point;
            _ = ecs.set(world, entity, components.gfx.ElementsRendererConfig, .{ .id = erc_id });
            ecs.remove(world, entity, components.shape.NeedsSetup);
        }
    }
}

const shaders = struct {
    fn genVertexShader(e: *const extractions, mesh_data: *const meshData) [:0]const u8 {
        const v_cfg = gfx.shadergen.vertex.VertexShaderGen.vertexShaderConfig{
            .debug = e.debug,
            .has_uniform_mat = e.has_uniform_mat,
            .has_ubo = e.has_ubo,
            .scale = e.scale,
            .rotation = e.rotation,
            .translation = e.translation,
            .has_texture_coords = mesh_data.texcoords != null,
            .has_normals = mesh_data.normals != null,
            .animation_block_index = e.animation_binding_point,
        };
        return gfx.shadergen.vertex.VertexShaderGen.genVertexShader(v_cfg) catch unreachable;
    }
    fn genFragmentShader(e: *const extractions, mesh_data: *const meshData) [:0]const u8 {
        const f_cfg = gfx.shadergen.fragment.FragmentShaderGen.fragmentShaderConfig{
            .debug = e.debug,
            .color = e.color,
            .has_texture_coords = mesh_data.texcoords != null,
            .has_texture = e.has_demo_cube_texture and mesh_data.texcoords != null,
            .has_normals = mesh_data.normals != null,
        };
        return gfx.shadergen.fragment.FragmentShaderGen.genFragmentShader(f_cfg) catch unreachable;
    }
};

const extractions = struct {
    rotation: ?math.vecs.Vflx4 = null,
    scale: ?math.vecs.Vflx4 = null,
    translation: ?math.vecs.Vflx4 = null,
    color: ?math.vecs.Vflx4 = null,
    debug: bool = false,
    has_ubo: bool = false,
    ubo_binding_point: gl.Uint = 0,
    has_uniform_mat: bool = false,
    uniform_mat: zm.Mat = zm.identity(),
    has_demo_cube_texture: bool = false,
    dc_t_beg: usize = 0,
    dc_t_end: usize = 0,
    has_animation_block: bool = false,
    animation_binding_point: ?gl.Uint = null,
    keyframes: ?[]game_state.ElementsRendererConfig.AnimationKeyFrame = null,

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
                var ssbo: gl.Uint = 0;
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
                    std.debug.print("\n\n\nSETTING ANIMATION BINDING POINT\n\n\n", .{});
                    e.animation_binding_point = ssbo;
                    e.has_animation_block = true;
                    e.keyframes = ar.toOwnedSlice(game.state.allocator) catch unreachable;
                }
            }
        }
    }

    fn extract(world: *ecs.world_t, entity: ecs.entity_t) extractions {
        var e = extractions{};
        if (ecs.get_id(world, entity, ecs.id(components.shape.Rotation))) |opaque_ptr| {
            const r: *const components.shape.Rotation = @ptrCast(@alignCast(opaque_ptr));
            e.rotation = r.toVec();
        }
        if (ecs.get_id(world, entity, ecs.id(components.shape.Scale))) |opaque_ptr| {
            const s: *const components.shape.Rotation = @ptrCast(@alignCast(opaque_ptr));
            e.scale = s.toVec();
        }
        if (ecs.get_id(world, entity, ecs.id(components.shape.Translation))) |opaque_ptr| {
            const t: *const components.shape.Rotation = @ptrCast(@alignCast(opaque_ptr));
            e.translation = t.toVec();
        }
        if (ecs.get_id(world, entity, ecs.id(components.shape.Color))) |opaque_ptr| {
            const c: *const components.shape.Rotation = @ptrCast(@alignCast(opaque_ptr));
            e.color = c.toVec();
        }
        if (ecs.has_id(world, entity, ecs.id(components.Debug))) {
            e.debug = true;
        }
        if (ecs.get_id(world, entity, ecs.id(components.shape.DemoCubeTexture))) |opaque_ptr| {
            const dct: *const components.shape.DemoCubeTexture = @ptrCast(@alignCast(opaque_ptr));
            e.has_demo_cube_texture = true;
            e.dc_t_beg = dct.beg;
            e.dc_t_end = dct.end;
        }
        if (ecs.get_id(world, entity, ecs.id(components.shape.UBO))) |opaque_ptr| {
            const u: *const components.shape.UBO = @ptrCast(@alignCast(opaque_ptr));
            e.has_ubo = true;
            e.ubo_binding_point = u.binding_point;
        }
        if (ecs.get_id(world, entity, ecs.id(components.screen.WorldLocation))) |opaque_ptr| {
            const u: *const components.screen.WorldLocation = @ptrCast(@alignCast(opaque_ptr));
            e.has_uniform_mat = true;
            e.uniform_mat = zm.translationV(u.toVec().value);
        }
        extractAnimation(&e, world, entity);
        return e;
    }
};

// :: Plane
fn plane() meshData {
    var p = zmesh.Shape.initPlane(1, 1);
    defer p.deinit();
    const positions: [][3]f32 = game.state.allocator.alloc([3]f32, p.positions.len) catch unreachable;
    @memcpy(positions, p.positions);
    const indices: []u32 = game.state.allocator.alloc(u32, p.indices.len) catch unreachable;
    @memcpy(indices, p.indices);
    var texcoords: ?[][2]gl.Float = null;
    if (p.texcoords) |_| {
        const tc: [][2]gl.Float = game.state.allocator.alloc([2]gl.Float, p.texcoords.?.len) catch unreachable;
        @memcpy(tc, p.texcoords.?);
        texcoords = tc;
    }
    var normals: ?[][3]gl.Float = null;
    if (p.normals) |_| {
        const ns: [][3]gl.Float = game.state.allocator.alloc([3]gl.Float, p.normals.?.len) catch unreachable;
        @memcpy(ns, p.normals.?);
        normals = ns;
    }
    return .{ .positions = positions, .indices = indices, .texcoords = texcoords, .normals = normals };
}

// :: Cube
const cube_positions: [36][3]gl.Float = .{
    // front
    .{ -0.5, -0.5, 0.5 },
    .{ 0.5, -0.5, 0.5 },
    .{ 0.5, 0.5, 0.5 },
    .{ -0.5, -0.5, 0.5 },
    .{ 0.5, 0.5, 0.5 },
    .{ -0.5, 0.5, 0.5 },

    // right
    .{ 0.5, -0.5, 0.5 },
    .{ 0.5, -0.5, -0.5 },
    .{ 0.5, 0.5, -0.5 },
    .{ 0.5, -0.5, 0.5 },
    .{ 0.5, 0.5, -0.5 },
    .{ 0.5, 0.5, 0.5 },
    // back
    .{ 0.5, -0.5, -0.5 },
    .{ -0.5, -0.5, -0.5 },
    .{ -0.5, 0.5, -0.5 },
    .{ 0.5, -0.5, -0.5 },
    .{ -0.5, 0.5, -0.5 },
    .{ 0.5, 0.5, -0.5 },
    // left
    .{ -0.5, -0.5, -0.5 },
    .{ -0.5, -0.5, 0.5 },
    .{ -0.5, 0.5, 0.5 },
    .{ -0.5, -0.5, -0.5 },
    .{ -0.5, 0.5, 0.5 },
    .{ -0.5, 0.5, -0.5 },
    // bottom
    .{ -0.5, -0.5, -0.5 },
    .{ 0.5, -0.5, -0.5 },
    .{ 0.5, -0.5, 0.5 },
    .{ -0.5, -0.5, -0.5 },
    .{ 0.5, -0.5, 0.5 },
    .{ -0.5, -0.5, 0.5 },
    // top
    .{ -0.5, 0.5, 0.5 },
    .{ 0.5, 0.5, 0.5 },
    .{ 0.5, 0.5, -0.5 },
    .{ -0.5, 0.5, 0.5 },
    .{ 0.5, 0.5, -0.5 },
    .{ -0.5, 0.5, -0.5 },
};

const cube_indices: [36]u32 = .{
    0, 1, 2, 3, 4, 5, // front
    6, 7, 8, 9, 10, 11, // right
    12, 13, 14, 15, 16, 17, // back
    18, 19, 20, 21, 22, 23, // left
    24, 25, 26, 27, 28, 29, // bottom
    30, 31, 32, 33, 34, 35, // top
};

const cube_texcoords: [36][2]gl.Float = .{
    // front
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
    // right
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
    // back
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
    // left
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
    // bottom
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 1.0 },
    .{ 0.0, 0.666 },
    .{ 1.0, 1.0 },
    .{ 0.0, 1.0 },
    // top
    .{ 0.0, 0.0 },
    .{ 1.0, 0.0 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.0 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
};

const cube_normals: [36][3]gl.Float = .{
    // front
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    // right
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    // backl
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    // left
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    // bottom
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    // top
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
};

fn cube() meshData {
    const positions: [][3]f32 = game.state.allocator.alloc([3]gl.Float, cube_positions.len) catch unreachable;
    @memcpy(positions, &cube_positions);
    const indices: []u32 = game.state.allocator.alloc(u32, cube_indices.len) catch unreachable;
    @memcpy(indices, &cube_indices);
    const texcoords: [][2]gl.Float = game.state.allocator.alloc([2]gl.Float, cube_texcoords.len) catch unreachable;
    @memcpy(texcoords, &cube_texcoords);
    const normals: [][3]gl.Float = game.state.allocator.alloc([3]gl.Float, cube_normals.len) catch unreachable;
    @memcpy(normals, &cube_normals);
    return .{ .positions = positions, .indices = indices, .texcoords = texcoords, .normals = normals };
}
