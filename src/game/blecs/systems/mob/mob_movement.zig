const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const math = @import("../../../math/math.zig");
const gfx = @import("../../../gfx/gfx.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "MobMovementSystem", ecs.PostLoad, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.mob.Mob) };
    desc.query.filter.terms[2] = .{ .id = ecs.id(components.mob.NeedsUpdate) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            turn(world, entity);
            move(world, entity);
        }
    }
}

const movement_duration: f32 = 0.1;

fn move(world: *ecs.world_t, entity: ecs.entity_t) void {
    const walking: *const components.mob.Walking = ecs.get(world, entity, components.mob.Walking) orelse return;
    if (walking.speed == 0) return;
    var position: *components.mob.Position = ecs.get_mut(world, entity, components.mob.Position) orelse return;
    const mob_speed: @Vector(4, f32) = @splat(walking.speed);
    position.position += walking.direction_vector * mob_speed;
    const now = game.state.input.lastframe;
    if (now - walking.last_moved > movement_duration) {
        ecs.remove(world, entity, components.mob.Walking);
    }
}

fn turn(world: *ecs.world_t, entity: ecs.entity_t) void {
    const turning: *const components.mob.Turning = ecs.get(world, entity, components.mob.Turning) orelse return;
    var rotation: *components.mob.Rotation = ecs.get_mut(world, entity, components.mob.Rotation) orelse return;
    rotation.rotation = turning.rotation;
    rotation.angle = turning.angle;
    const now = game.state.input.lastframe;
    if (now - turning.last_moved > movement_duration) {
        ecs.remove(world, entity, components.mob.Turning);
    }
}
