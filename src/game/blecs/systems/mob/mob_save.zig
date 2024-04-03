const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const save_job = @import("../../../thread/jobs/jobs_save.zig");

const save_after_seconds: f64 = 15;

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "MobSaveSystem", ecs.OnStore, @constCast(&s));
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
            const m: *components.mob.Mob = ecs.get_mut(world, entity, components.mob.Mob) orelse continue;
            ecs.remove(world, entity, components.mob.DidUpdate);
            if (ecs.has_id(world, entity, ecs.id(components.mob.Falling))) continue;
            var loc: @Vector(4, f32) = .{ 1, 1, 1, 1 };
            var rotation: @Vector(4, f32) = .{ 0, 0, 0, 1 };
            var angle: f32 = 0;
            if (ecs.get(world, entity, components.mob.Position)) |p| {
                loc = p.position;
            }
            if (ecs.get(world, entity, components.mob.Rotation)) |r| {
                rotation = r.rotation;
                angle = r.angle;
            }
            if (m.last_saved + save_after_seconds < game.state.input.lastframe) {
                var data = save_job.SaveData{
                    .player_position = .{
                        .loc = loc,
                        .rotation = rotation,
                        .angle = angle,
                    },
                };

                var cs = game.state.gfx.game_chunks.valueIterator();
                var to_save: usize = 0;
                while (cs.next()) |cc| {
                    if (cc.*.updated) {
                        data.chunks_updated[to_save] = cc.*;
                        to_save += 1;
                        if (to_save >= data.chunks_updated.len) break;
                    }
                }
                _ = game.state.jobs.save(data);
                m.last_saved = game.state.input.lastframe;
            }
        }
    }
}
