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
            if (checkMob(world, entity, m[i])) return;
            std.debug.print("mob is falling\n", .{});
        }
    }
}

fn checkMob(world: *ecs.world_t, entity: ecs.entity_t, mob: components.mob.Mob) bool {
    var loc: @Vector(4, f32) = .{ 1, 1, 1, 1 };
    if (ecs.get(world, entity, components.mob.Position)) |p| {
        loc = p.position;
    } else {
        return true;
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
