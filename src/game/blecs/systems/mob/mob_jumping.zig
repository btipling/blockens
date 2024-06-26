const system_name = "MobJumpingSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.OnUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.mob.Mob) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.mob.Jumping) };
    desc.run = if (config.use_tracy) runWithTrace else run;
    return desc;
}

fn runWithTrace(it: *ecs.iter_t) callconv(.C) void {
    ztracy.Message(system_name);
    const tracy_zone = ztracy.ZoneNC(@src(), system_name, 0xff_00_ff_f0);
    defer tracy_zone.End();
    return run(it);
}

const jump_time: f32 = 0.4;
const jump_velocity: f32 = 4;

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const m = ecs.field(it, components.mob.Mob, 1) orelse continue;
            const j = ecs.field(it, components.mob.Jumping, 2) orelse continue;

            // Jumps only last for so long, the jump time is currently hard coded and ends when
            // the duration since jump start is greater than the jump time.
            const now = game.state.input.lastframe;
            const jump_duration = now - j[i].jumped_at;
            const p: *components.mob.Position = ecs.get_mut(world, entity, components.mob.Position) orelse continue;
            if (jump_duration > jump_time) {
                ecs.remove(world, entity, components.mob.Jumping);
                continue;
            }

            // Given the current duration of the jump and the velocity of the jump determine where
            // the mob should be at relative to the jump starting point.
            // This is done in small increments to test for collisions.
            // If a collision is detected block the jump from going further.

            // FIXME: collision should end the jump early this doesn't seem to right now.
            var pos = p.position;
            const done = j[i].starting_position[1] + jump_duration * jump_velocity;
            while (pos[1] < done) {
                pos[1] += 0.01;
                if (!checkMob(pos, m[i])) {
                    pos = p.position;
                    break;
                }
            }
            p.position = pos;
            ecs.add(game.state.world, game.state.entities.player, components.mob.NeedsUpdate);
        }
    }
}

fn checkMob(loc: @Vector(4, f32), mob: components.mob.Mob) bool {
    const mob_data: *const game_mob.Mob = game.state.gfx.mob_data.get(mob.mob_id) orelse return true;
    const bottom_bounds = mob_data.getTopBounds();
    for (bottom_bounds) |coords| {
        if (!canJump(coords, loc)) return false;
    }
    return true;
}

fn canJump(bbc: [3]f32, mob_loc: @Vector(4, f32)) bool {
    const bbc_v: @Vector(4, f32) = .{ bbc[0], bbc[1], bbc[2], 1 };
    const bbc_ws = zm.mul(bbc_v, zm.translationV(mob_loc));
    const res = chunk.getBlockId(bbc_ws);
    if (!res.read) return true;
    return res.data & 0x0F == 0;
}

const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const game_mob = @import("../../../mob.zig");
const block = @import("../../../block/block.zig");
const chunk = block.chunk;
