const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const chunk = @import("../../../chunk.zig");
const game_mob = @import("../../../mob.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "MobFallingSystem", ecs.OnUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.mob.Mob) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.mob.DidUpdate) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const m = ecs.field(it, components.mob.Mob, 1) orelse continue;
            const p = ecs.get(world, entity, components.mob.Position) orelse continue;
            const loc = p.position;

            if (checkMob(loc, m[i])) {
                endFall(world, entity);
                continue;
            }
            ecs.remove(world, entity, components.mob.Walking);
            if (dropMobAndEnd(world, entity, m[i])) {
                endFall(world, entity);
                continue;
            }
        }
    }
}

fn endFall(world: *ecs.world_t, entity: ecs.entity_t) void {
    if (ecs.has_id(world, entity, ecs.id(components.mob.Falling))) {
        const mp: *components.mob.Position = ecs.get_mut(
            world,
            entity,
            components.mob.Position,
        ) orelse std.debug.panic("No position for mob\n", .{});
        mp.position = .{ mp.position[0], @floor(mp.position[1]), mp.position[2], mp.position[3] };
        ecs.remove(world, entity, components.mob.Falling);
    }
}

const starting_velocity: f32 = 0.0005;
const gravity: f32 = 0.01;
const max_velocity: f32 = 2;
fn dropMobAndEnd(world: *ecs.world_t, entity: ecs.entity_t, mob: components.mob.Mob) bool {
    const mp: *components.mob.Position = ecs.get_mut(
        world,
        entity,
        components.mob.Position,
    ) orelse std.debug.panic("No position for mob\n", .{});
    ecs.add(world, entity, components.mob.NeedsUpdate);
    if (!ecs.has_id(world, entity, ecs.id(components.mob.Falling))) {
        var updated_pos = mp.position;
        updated_pos[1] -= starting_velocity;
        mp.position = updated_pos;
        _ = ecs.set(
            world,
            entity,
            components.mob.Falling,
            .{
                .velocity = starting_velocity,
                .started = game.state.input.lastframe,
            },
        );
        return false;
    }
    const mf: *components.mob.Falling = ecs.get_mut(
        world,
        entity,
        components.mob.Falling,
    ) orelse std.debug.panic("expected falling to be present\n", .{});
    const velocity = mf.velocity;
    const now: f32 = game.state.input.lastframe;
    const delta: f32 = now - mf.started;
    var updated_pos = mp.position;
    const max_change_per_check: f32 = 0.05;
    var drop_change: f32 = max_change_per_check;
    if (velocity < max_change_per_check) {
        updated_pos[1] -= velocity;
    } else {
        while (drop_change < velocity) {
            updated_pos[1] -= max_change_per_check;
            drop_change += max_change_per_check;
            if (checkMob(updated_pos, mob)) return true;
        }
    }
    if (updated_pos[1] < 0) return true;
    mp.position = updated_pos;
    const new_velocity = velocity + gravity * delta;
    if (new_velocity < max_velocity) {
        mf.velocity = new_velocity;
    }
    return false;
}

fn checkMob(loc: @Vector(4, f32), mob: components.mob.Mob) bool {
    const mob_data: *const game_mob.Mob = game.state.gfx.mob_data.get(mob.mob_id) orelse return true;
    const bottom_bounds = mob_data.getBottomBounds();
    var loc_test = loc;
    loc_test[2] -= 0.5;
    const res = chunk.getBlockId(loc_test);
    if (!res.read) return true;
    if (res.data & 0x0F != 0) {
        return true;
    }
    for (bottom_bounds) |coords| {
        if (onGround(coords, loc)) return true;
    }
    return false;
}

fn onGround(bbc: [3]f32, mob_loc: @Vector(4, f32)) bool {
    var bbc_v: @Vector(4, f32) = .{ bbc[0], bbc[1], bbc[2], 1 };
    bbc_v[1] -= 0.1; // checking below
    const bbc_ws = zm.mul(bbc_v, zm.translationV(mob_loc));
    if (bbc_ws[1] < 0) return true;
    const res = chunk.getBlockId(bbc_ws);
    if (!res.read) return true;
    return res.data & 0x0F != 0;
}
