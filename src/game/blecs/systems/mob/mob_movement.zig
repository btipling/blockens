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
            turn(world, entity);
            move(world, entity, m[i]);
        }
    }
}

const movement_duration: f32 = 0.1;

fn move(world: *ecs.world_t, entity: ecs.entity_t, mob: components.mob.Mob) void {
    const walking: *const components.mob.Walking = ecs.get(world, entity, components.mob.Walking) orelse return;
    if (walking.speed > 0 and canMove(world, entity, mob, walking.direction_vector)) {
        var position: *components.mob.Position = ecs.get_mut(world, entity, components.mob.Position) orelse return;
        const mob_speed: @Vector(4, f32) = @splat(walking.speed);
        position.position += walking.direction_vector * mob_speed;
    }
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

fn canMove(world: *ecs.world_t, entity: ecs.entity_t, mob: components.mob.Mob, direction_vector: @Vector(4, f32)) bool {
    var loc: @Vector(4, f32) = .{ 1, 1, 1, 1 };
    if (ecs.get(world, entity, components.mob.Position)) |p| {
        loc = p.position;
    } else {
        return false;
    }
    const mob_data: *const game_mob.Mob = game.state.gfx.mob_data.get(mob.mob_id) orelse return false;
    const bounds = mob_data.getAllBounds();
    const norm_vec: @Vector(4, f32) = zm.normalize3(direction_vector);
    const distance: @Vector(4, f32) = @splat(1);
    const updated_dir_vec = norm_vec * distance;
    for (bounds) |coords| {
        if (hitObstacle(coords, loc, updated_dir_vec)) return false;
    }
    return true;
}

fn hitObstacle(bbc: [3]f32, mob_loc: @Vector(4, f32), updated_dir_vec: @Vector(4, f32)) bool {
    const bbc_v: @Vector(4, f32) = .{ bbc[0], bbc[1], bbc[2], 1 };
    const vec_to_check = bbc_v + updated_dir_vec;
    const bbc_ws = zm.mul(vec_to_check, zm.translationV(mob_loc));
    const chunk_pos = chunk.positionFromWorldLocation(bbc_ws);

    const wp = chunk.worldPosition.initFromPositionV(chunk_pos);
    const chunk_data = game.state.gfx.game_chunks.get(wp) orelse return false; // no chunk in that direction
    const chunk_local_pos = chunk.chunkPosFromWorldLocation(bbc_ws);
    const chunk_index = chunk.getIndexFromPositionV(chunk_local_pos);
    const block_id: u32 = chunk_data.data[chunk_index];

    return block_id != 0; // if not air, hit obstacle
}
