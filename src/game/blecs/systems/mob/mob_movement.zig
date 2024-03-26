const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const game_mob = @import("../../../mob.zig");
const chunk = @import("../../../chunk.zig");

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
            const m = ecs.field(it, components.mob.Mob, 1) orelse continue;
            turn(world, entity, m[i]);
            move(world, entity, m[i]);
        }
    }
}

const movement_duration: f32 = 0.1;

fn move(world: *ecs.world_t, entity: ecs.entity_t, mob: components.mob.Mob) void {
    const walking: *const components.mob.Walking = ecs.get(world, entity, components.mob.Walking) orelse return;
    var position: *components.mob.Position = ecs.get_mut(world, entity, components.mob.Position) orelse return;
    if (walking.speed > 0 and canMove(world, entity, mob, walking)) {
        const mob_speed: @Vector(4, f32) = @splat(walking.speed);
        position.position += walking.direction_vector * mob_speed;
    }
    const now = game.state.input.lastframe;
    if (now - walking.last_moved > movement_duration) {
        ecs.remove(world, entity, components.mob.Walking);
    }
}

fn turn(world: *ecs.world_t, entity: ecs.entity_t, _: components.mob.Mob) void {
    const turning: *const components.mob.Turning = ecs.get(world, entity, components.mob.Turning) orelse return;
    var rotation: *components.mob.Rotation = ecs.get_mut(world, entity, components.mob.Rotation) orelse return;
    rotation.rotation = turning.rotation;
    rotation.angle = turning.angle;
    const now = game.state.input.lastframe;
    if (now - turning.last_moved > movement_duration) {
        ecs.remove(world, entity, components.mob.Turning);
    }
}

fn canMove(world: *ecs.world_t, entity: ecs.entity_t, mob: components.mob.Mob, walking: *const components.mob.Walking) bool {
    var rot: @Vector(4, f32) = .{ 1, 0, 0, 0 };
    if (ecs.get(world, entity, components.mob.Rotation)) |r| {
        rot = r.rotation;
    } else {
        return false;
    }
    const bounds_to_check = getFacingBounds(
        world,
        entity,
        mob,
        rot,
        walking.direction_vector,
        0.05,
    );
    for (bounds_to_check) |bbc_ws| {
        if (hitObstacle(bbc_ws)) return false;
    }
    return true;
}

fn getFacingBounds(
    world: *ecs.world_t,
    entity: ecs.entity_t,
    mob: components.mob.Mob,
    rot: @Vector(4, f32),
    direction_vector: @Vector(4, f32),
    distance_to_check: f32,
) [4]@Vector(4, f32) {
    var loc: @Vector(4, f32) = .{ 1, 1, 1, 1 };
    if (ecs.get(world, entity, components.mob.Position)) |p| {
        loc = p.position;
    } else std.debug.panic("expected a location when getting facing bounds\n", .{});
    const mob_data: *const game_mob.Mob = game.state.gfx.mob_data.get(mob.mob_id) orelse @panic("nope");
    var bounds_to_check: [4]@Vector(4, f32) = undefined;
    var size: usize = 0;
    const norm_vec: @Vector(4, f32) = zm.normalize3(direction_vector);
    const distance: @Vector(4, f32) = @splat(distance_to_check);
    const updated_dir_vec = norm_vec * distance;
    const bounds = mob_data.getAllBounds();
    outer: for (bounds) |bbc| {
        const bbc_v: @Vector(4, f32) = .{ bbc[0], bbc[1], bbc[2], 1 };
        const vec_to_check = bbc_v + updated_dir_vec;
        const m = zm.mul(zm.quatToMat(rot), zm.translationV(loc));
        var bbc_ws = zm.mul(vec_to_check, m);
        var ii: usize = 0;
        inner: while (ii < 4) : (ii += 1) {
            if (ii == size) {
                bounds_to_check[ii] = bbc_ws;
                size += 1;
                continue :outer;
            }
            switch (aInFrontOfB(bbc_ws, bounds_to_check[ii], direction_vector)) {
                .front => {
                    const t = bounds_to_check[ii];
                    bounds_to_check[ii] = bbc_ws;
                    bbc_ws = t;
                    // sK
                    continue :inner;
                },
                else => continue :inner,
            }
        }
    }
    return bounds_to_check;
}

const bound_order = enum {
    front,
    behind,
    parallel,
};

fn aInFrontOfB(pa: @Vector(4, f32), pb: @Vector(4, f32), direction_vector: @Vector(4, f32)) bound_order {
    const pv: @Vector(4, f32) = @round(pb) - @round(pa);
    const product = zm.dot3(pv, direction_vector);
    if (product[0] > 0) {
        return .behind;
    }
    if (product[0] < 0) {
        return .front;
    }
    return .parallel;
}

fn hitObstacle(bbc_ws: @Vector(4, f32)) bool {
    const chunk_pos = chunk.positionFromWorldLocation(bbc_ws);

    const wp = chunk.worldPosition.initFromPositionV(chunk_pos);
    const chunk_data = game.state.gfx.game_chunks.get(wp) orelse return false; // no chunk in that direction
    const chunk_local_pos = chunk.chunkPosFromWorldLocation(bbc_ws);
    const chunk_index = chunk.getIndexFromPositionV(chunk_local_pos);
    const block_id: u32 = chunk_data.data[chunk_index];
    return block_id != 0; // if not air, hit obstacle
}
