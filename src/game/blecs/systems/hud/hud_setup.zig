const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
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

            var plane = zmesh.Shape.initPlane(1, 1);
            defer plane.deinit();

            const vertexShader: [:0]const u8 = gfx.shadergen.ShaderGen.genVertexShader(game.state.allocator) catch unreachable;
            const fragmentShader: [:0]const u8 = gfx.shadergen.ShaderGen.genFragmentShader(game.state.allocator) catch unreachable;
            const positions: [][3]f32 = game.state.allocator.alloc([3]f32, plane.positions.len) catch unreachable;
            @memcpy(positions, plane.positions);
            _ = ecs.set(world, entity, components.gfx.ElementsRendererConfig, .{
                .vertexShader = vertexShader,
                .fragmentShader = fragmentShader,
                .positions = positions,
            });
            ecs.remove(world, entity, components.shape.NeedsSetup);
        }
    }
}
