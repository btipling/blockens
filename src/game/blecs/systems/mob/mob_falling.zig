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
            const not_falling = checkMob(world, entity, m[i]);
            if (not_falling) {
                if (ecs.has_id(world, entity, ecs.id(components.mob.Falling))) {
                    ecs.remove(world, entity, components.mob.Falling);
                }
                continue;
            }
            dropMob(world, entity);
        }
    }
}

const gravity: f32 = 1;
const starting_velocity: f32 = 0.25;
const max_velocity = 0.75;
fn dropMob(world: *ecs.world_t, entity: ecs.entity_t) void {
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
                .started = std.time.milliTimestamp(),
            },
        );
        return;
    }
    const mf: *components.mob.Falling = ecs.get_mut(
        world,
        entity,
        components.mob.Falling,
    ) orelse std.debug.panic("expected falling to be present\n", .{});
    const now: i64 = std.time.milliTimestamp();
    var delta: f32 = @as(f32, @floatFromInt(now - mf.started)) / 1000;
    delta += 1;
    const new_velocity = mf.velocity * gravity * delta;
    var updated_pos = mp.position;
    updated_pos[1] -= mf.velocity;
    if (updated_pos[1] < 0) return;
    mp.position = updated_pos;
    if (new_velocity > max_velocity) return;
    mf.velocity = new_velocity;
}

fn checkMob(world: *ecs.world_t, entity: ecs.entity_t, mob: components.mob.Mob) bool {
    var loc: @Vector(4, f32) = .{ 1, 1, 1, 1 };
    if (ecs.get(world, entity, components.mob.Position)) |p| {
        loc = p.position;
    } else {
        return true;
    }
    if (loc[1] < 0) {
        return false;
    }
    const mob_data: *const game_mob.Mob = game.state.gfx.mob_data.get(mob.mob_id) orelse return true;
    const bottom_bounds = mob_data.getBottomBounds();
    for (bottom_bounds) |coords| {
        if (onGround(coords, loc)) return true;
    }
    return false;
}

fn onGround(bbc: [3]f32, mob_loc: @Vector(4, f32)) bool {
    var bbc_v: @Vector(4, f32) = .{ bbc[0], bbc[1], bbc[2], 1 };
    bbc_v[1] -= 1; // The coordinate below.
    const bbc_ws = zm.mul(bbc_v, zm.translationV(mob_loc));
    const chunk_pos = chunk.positionFromWorldLocation(bbc_ws);

    const wp = chunk.worldPosition.initFromPositionV(chunk_pos);
    const chunk_data = game.state.gfx.game_chunks.get(wp) orelse return false;
    const chunk_local_pos = chunk.chunkPosFromWorldLocation(bbc_ws);
    const chunk_index = chunk.getIndexFromPositionV(chunk_local_pos);
    const block_id: u32 = chunk_data.data[chunk_index];

    return block_id != 0;
}