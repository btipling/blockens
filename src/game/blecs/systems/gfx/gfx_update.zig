const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const components = @import("../../components/components.zig");
const gfx = @import("../../../gfx/gfx.zig");
const game = @import("../../../game.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "GfxUPdateSystem", ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.gfx.ElementsRenderer) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.gfx.NeedsUniformUpdate) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const ers: []components.gfx.ElementsRenderer = ecs.field(it, components.gfx.ElementsRenderer, 1) orelse return;
            const er = ers[i];
            ecs.remove(world, entity, components.mob.NeedsSetup);
            var m = zm.identity();
            if (ecs.get(world, entity, components.screen.WorldRotation)) |r| {
                m = zm.mul(m, zm.quatToMat(r.rotation));
            }
            if (ecs.get(world, entity, components.screen.WorldLocation)) |p| {
                m = zm.mul(m, zm.translationV(p.loc));
            }
            gfx.Gfx.setUniformMat(gfx.constants.TransformMatName, er.program, m);
        }
    }
}
