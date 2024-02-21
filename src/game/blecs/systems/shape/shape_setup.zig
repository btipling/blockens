const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
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

            var rotation: ?math.vecs.Vflx4 = null;
            var scale: ?math.vecs.Vflx4 = null;
            var translation: ?math.vecs.Vflx4 = null;
            var color: ?math.vecs.Vflx4 = null;
            var debug = false;
            var has_ubo = false;
            var ubo_binding_point: gl.Uint = 0;
            var has_uniform_mat = false;
            var has_demo_cube_texture = false;
            var uniform_mat = zm.identity();
            if (ecs.get_id(world, entity, ecs.id(components.shape.Rotation))) |opaque_ptr| {
                const r: *const components.shape.Rotation = @ptrCast(@alignCast(opaque_ptr));
                rotation = r.toVec();
            }
            if (ecs.get_id(world, entity, ecs.id(components.shape.Scale))) |opaque_ptr| {
                const s: *const components.shape.Rotation = @ptrCast(@alignCast(opaque_ptr));
                scale = s.toVec();
            }
            if (ecs.get_id(world, entity, ecs.id(components.shape.Translation))) |opaque_ptr| {
                const t: *const components.shape.Rotation = @ptrCast(@alignCast(opaque_ptr));
                translation = t.toVec();
            }
            if (ecs.get_id(world, entity, ecs.id(components.shape.Color))) |opaque_ptr| {
                const c: *const components.shape.Rotation = @ptrCast(@alignCast(opaque_ptr));
                color = c.toVec();
            }
            if (ecs.has_id(world, entity, ecs.id(components.Debug))) {
                debug = true;
            }
            if (ecs.has_id(world, entity, ecs.id(components.shape.DemoCubeTexture))) {
                has_demo_cube_texture = true;
            }
            if (ecs.get_id(world, entity, ecs.id(components.shape.UBO))) |opaque_ptr| {
                const u: *const components.shape.UBO = @ptrCast(@alignCast(opaque_ptr));
                has_ubo = true;
                ubo_binding_point = u.binding_point;
            }
            if (ecs.get_id(world, entity, ecs.id(components.screen.WorldLocation))) |opaque_ptr| {
                const u: *const components.screen.WorldLocation = @ptrCast(@alignCast(opaque_ptr));
                has_uniform_mat = true;
                uniform_mat = zm.translationV(u.toVec().value);
            }

            const v_cfg = gfx.shadergen.ShaderGen.vertexShaderConfig{
                .debug = debug,
                .has_uniform_mat = has_uniform_mat,
                .has_ubo = has_ubo,
                .scale = scale,
                .rotation = rotation,
                .translation = translation,
                .has_texture_coords = mesh_data.texcoords != null,
                .has_normals = mesh_data.normals != null,
            };
            const vertexShader: [:0]const u8 = gfx.shadergen.ShaderGen.genVertexShader(game.state.allocator, v_cfg) catch unreachable;
            const f_cfg = gfx.shadergen.ShaderGen.fragmentShaderConfig{
                .debug = debug,
                .color = color,
                .has_texture_coords = mesh_data.texcoords != null,
                .has_texture = mesh_data.texcoords != null,
                .has_normals = mesh_data.normals != null,
            };
            const fragmentShader: [:0]const u8 = gfx.shadergen.ShaderGen.genFragmentShader(game.state.allocator, f_cfg) catch unreachable;
            var erc = game.state.allocator.create(game_state.ElementsRendererConfig) catch unreachable;
            erc.* = .{
                .vertexShader = vertexShader,
                .fragmentShader = fragmentShader,
                .positions = mesh_data.positions,
                .indices = mesh_data.indices,
                .transform = null,
                .ubo_binding_point = null,
                .has_demo_cube_texture = has_demo_cube_texture,
            };
            const erc_id = ecs.new_id(world);
            game.state.gfx.renderConfigs.put(erc_id, erc) catch unreachable;
            if (has_uniform_mat) erc.transform = uniform_mat;
            if (has_ubo) erc.ubo_binding_point = ubo_binding_point;
            _ = ecs.set(world, entity, components.gfx.ElementsRendererConfig, .{ .id = erc_id });
            ecs.remove(world, entity, components.shape.NeedsSetup);
        }
    }
}

// :: Plane
fn plane() meshData {
    var p = zmesh.Shape.initPlane(1, 1);
    defer p.deinit();
    const positions: [][3]f32 = game.state.allocator.alloc([3]f32, p.positions.len) catch unreachable;
    @memcpy(positions, p.positions);
    const indices: []u32 = game.state.allocator.alloc(u32, p.indices.len) catch unreachable;
    @memcpy(indices, p.indices);
    return .{ .positions = positions, .indices = indices };
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
