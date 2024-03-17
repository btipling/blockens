const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const components = @import("../../../components/components.zig");
const entities = @import("../../../entities/entities.zig");
const game = @import("../../../../game.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "SettingsDemoChunkSystem", ecs.OnLoad, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.Screen) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.screen.NeedsDemoChunk) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    const screen: *const components.screen.Screen = ecs.get(
        world,
        game.state.entities.screen,
        components.screen.Screen,
    ) orelse unreachable;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            ecs.remove(world, entity, components.screen.NeedsDemoChunk);
            if (!ecs.has_id(world, screen.current, ecs.id(components.screen.Settings))) {
                continue;
            }
            entities.screen.initDemoChunk();
        }
    }
}
