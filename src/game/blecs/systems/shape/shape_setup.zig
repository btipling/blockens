const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const zmesh = @import("zmesh");
const zm = @import("zmath");
const tags = @import("../../tags.zig");
const game = @import("../../../game.zig");
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

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];

            var rotation: ?math.vecs.Vflx4 = null;
            var scale: ?math.vecs.Vflx4 = null;
            var translation: ?math.vecs.Vflx4 = null;
            var color: ?math.vecs.Vflx4 = null;
            var debug = false;
            var has_ubo = false;
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
            if (ecs.has_id(world, entity, ecs.id(components.shape.UBO))) {
                has_ubo = true;
            }

            var plane = zmesh.Shape.initPlane(1, 1);
            defer plane.deinit();
            const v_cfg = gfx.shadergen.ShaderGen.vertexShaderConfig{
                .debug = debug,
                .has_uniform_mat = debug,
                .has_ubo = has_ubo,
                .scale = scale,
                .rotation = rotation,
                .translation = translation,
            };
            const vertexShader: [:0]const u8 = gfx.shadergen.ShaderGen.genVertexShader(game.state.allocator, v_cfg) catch unreachable;
            const f_cfg = gfx.shadergen.ShaderGen.fragmentShaderConfig{
                .debug = debug,
                .color = color,
            };
            const fragmentShader: [:0]const u8 = gfx.shadergen.ShaderGen.genFragmentShader(game.state.allocator, f_cfg) catch unreachable;
            const positions: [][3]f32 = game.state.allocator.alloc([3]f32, plane.positions.len) catch unreachable;
            @memcpy(positions, plane.positions);
            const indices: []u32 = game.state.allocator.alloc(u32, plane.indices.len) catch unreachable;
            @memcpy(indices, plane.indices);
            var erc: components.gfx.ElementsRendererConfig = .{
                .vertexShader = vertexShader,
                .fragmentShader = fragmentShader,
                .positions = positions,
                .indices = indices,
                .transform = null,
            };
            if (debug) erc.transform = zm.identity();
            _ = ecs.set(world, entity, components.gfx.ElementsRendererConfig, erc);
            ecs.remove(world, entity, components.shape.NeedsSetup);
        }
    }
}
