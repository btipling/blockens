const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const tags = @import("../../tags.zig");
const game = @import("../../../game.zig");
const gfx = @import("../../../shape/gfx/gfx.zig");
const components = @import("../../components/components.zig");

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(tags.Hud) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.shape.Plane) };
    desc.query.filter.terms[2] = .{ .id = ecs.id(components.shape.NeedsSetup) };
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const planes: []components.shape.Plane = ecs.field(it, components.shape.Plane, 2) orelse return;
            _ = planes[i];
            const vertexShader: [:0]const u8 = gfx.shadergen.ShaderGen.genVertexShader(game.state.allocator) catch unreachable;
            const fragmentShader: [:0]const u8 = gfx.shadergen.ShaderGen.genFragmentShader(game.state.allocator) catch unreachable;
            _ = ecs.set(world, entity, components.gfx.ElementsRendererConfig, .{
                .vertexShader = vertexShader,
                .fragmentShader = fragmentShader,
            });
            ecs.remove(world, entity, components.shape.NeedsSetup);
        }
    }
}
