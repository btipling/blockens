const std = @import("std");
const ecs = @import("zflecs");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const helpers = @import("../../helpers.zig");
const game = @import("../../../game.zig");
const game_state = @import("../../../state/state.zig");
const cltf_mesh = @import("../../../gfx/cltf_mesh.zig");
const gfx = @import("../../../gfx/gfx.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "MobUpdateSystem", ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.mob.Mob) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.mob.Walking) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const m: []components.mob.Mob = ecs.field(it, components.mob.Mob, 1) orelse return;
            updateMob(world, entity, m[i].data_entity) catch unreachable;
        }
    }
}

fn updateMob(world: *ecs.world_t, entity: ecs.entity_t, data_entity: ecs.entity_t) !void {
    var loc: @Vector(4, f32) = .{ 1, 1, 1, 1 };
    var rotation: @Vector(4, f32) = .{ 0, 0, 0, 1 };
    if (ecs.get(world, entity, components.mob.Position)) |p| {
        loc = p.position;
    }
    if (ecs.get(world, entity, components.mob.Rotation)) |r| {
        rotation = r.rotation;
    }
    var it = ecs.children(world, data_entity);
    while (ecs.iter_next(&it)) {
        for (0..it.count()) |i| {
            const child_entity = it.entities()[i];
            _ = ecs.set(world, child_entity, components.screen.WorldRotation, .{ .rotation = rotation });
            _ = ecs.set(world, child_entity, components.screen.WorldLocation, .{ .loc = loc });
            ecs.add(world, child_entity, components.gfx.NeedsUniformUpdate);
        }
    }
}
