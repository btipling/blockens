const system_name = "GfxUpdateSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .oper = .And, .id = ecs.id(components.gfx.ElementsRenderer) };
    desc.query.filter.terms[1] = .{ .oper = .And, .id = ecs.id(components.gfx.NeedsUniformUpdate) };
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
            const ers: []components.gfx.ElementsRenderer = ecs.field(it, components.gfx.ElementsRenderer, 1) orelse continue;
            const er = ers[i];
            if (!ecs.has_id(world, entity, ecs.id(components.gfx.NeedsUniformUpdate))) {
                continue;
            }
            ecs.remove(world, entity, components.gfx.NeedsUniformUpdate);
            var m = zm.identity();
            if (ecs.get(world, entity, components.screen.WorldRotation)) |r| {
                m = zm.mul(m, zm.quatToMat(r.rotation));
            }
            if (ecs.get(world, entity, components.screen.WorldLocation)) |p| {
                m = zm.mul(m, zm.translationV(p.loc));
            }
            gfx.gl.Gl.setUniformMat(gfx.constants.TransformMatName, er.program, m);
        }
    }
}

const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../components/components.zig");
const gfx = @import("../../../gfx/gfx.zig");
const game = @import("../../../game.zig");
