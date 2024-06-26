const system_name = "BlockMeshingSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.block.Chunk) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.block.NeedsMeshing) };
    desc.run = if (config.use_tracy) runWithTrace else run;
    return desc;
}

fn runWithTrace(it: *ecs.iter_t) callconv(.C) void {
    ztracy.Message(system_name);
    const tracy_zone = ztracy.ZoneNC(@src(), system_name, 0xff_00_ff_f0);
    defer tracy_zone.End();
    return run(it);
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const ch_c: []components.block.Chunk = ecs.field(it, components.block.Chunk, 1) orelse continue;
            const wp = ch_c[i].wp;
            const parent: ecs.entity_t = ecs.get_parent(world, entity);
            ecs.remove(world, entity, components.block.NeedsMeshing);
            var c: *chunk.Chunk = undefined;
            if (parent == entities.screen.game_data) {
                c = game.state.blocks.game_chunks.get(wp) orelse continue;
            } else {
                c = game.state.blocks.settings_chunks.get(wp) orelse continue;
            }
            _ = game.state.jobs.meshChunk(world, entity, c);
        }
    }
}

const std = @import("std");
const ecs = @import("zflecs");
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const chunk = @import("../../../block/block.zig").chunk;
