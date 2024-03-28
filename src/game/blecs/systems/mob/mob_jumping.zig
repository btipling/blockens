const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "MobJumpingSystem", ecs.OnUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.mob.Mob) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.mob.Jumping) };
    desc.run = run;
    return desc;
}

const jump_time: f32 = 0.4;
const jump_velocity: f32 = 3;

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const j = ecs.field(it, components.mob.Jumping, 2) orelse continue;
            const now = game.state.input.lastframe;
            const jump_duration = now - j[i].jumped_at;
            if (jump_duration > jump_time) {
                ecs.remove(world, entity, components.mob.Jumping);
                continue;
            }
            const p: *components.mob.Position = ecs.get_mut(world, entity, components.mob.Position) orelse continue;

            p.position[1] = j[i].starting_position[1] + jump_duration * jump_velocity;
            ecs.add(game.state.world, game.state.entities.player, components.mob.NeedsUpdate);
        }
    }
}
