const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const zmesh = @import("zmesh");
const zm = @import("zmath");
const tags = @import("../../tags.zig");
const game = @import("../../../game.zig");
const gfx = @import("../../../shape/gfx/gfx.zig");
const components = @import("../../components/components.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "HudSetupSystem", ecs.OnUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(tags.Hud) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.shape.Plane) };
    desc.query.filter.terms[2] = .{ .id = ecs.id(components.shape.NeedsSetup) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const pls: []components.shape.Plane = ecs.field(it, components.shape.Plane, 2) orelse return;

            var plane = zmesh.Shape.initPlane(1, 1);
            defer plane.deinit();

            const v_cfg = gfx.shadergen.ShaderGen.vertexShaderConfig{
                .has_uniform_mat = true,
            };
            const vertexShader: [:0]const u8 = gfx.shadergen.ShaderGen.genVertexShader(game.state.allocator, v_cfg) catch unreachable;
            const f_cfg = gfx.shadergen.ShaderGen.fragmentShaderConfig{
                .color = pls[i].color,
            };
            const fragmentShader: [:0]const u8 = gfx.shadergen.ShaderGen.genFragmentShader(game.state.allocator, f_cfg) catch unreachable;
            const positions: [][3]f32 = game.state.allocator.alloc([3]f32, plane.positions.len) catch unreachable;
            @memcpy(positions, plane.positions);
            const indices: []u32 = game.state.allocator.alloc(u32, plane.indices.len) catch unreachable;
            @memcpy(indices, plane.indices);
            _ = ecs.set(world, entity, components.gfx.ElementsRendererConfig, .{
                .vertexShader = vertexShader,
                .fragmentShader = fragmentShader,
                .positions = positions,
                .indices = indices,
                .transform = zm.scaling(0.5, 0.5, 0.5),
            });
            ecs.remove(world, entity, components.shape.NeedsSetup);
        }
    }
}
