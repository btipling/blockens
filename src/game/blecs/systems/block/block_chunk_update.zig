const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const chunk = @import("../../../chunk.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "BlockChunkUpdateSystem", ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.block.ChunkUpdate) };
    desc.run = run;
    return desc;
}

var current_block_id: u8 = 0;

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    var updated_chunks: [10]?chunk.worldPosition = [_]?chunk.worldPosition{null} ** 10;
    var has_reached_max_chunks = false;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            if (has_reached_max_chunks) continue; // Really unlikely to update 10! chunks, but will handle the rest later.
            const entity = it.entities()[i];
            const cu: []components.block.ChunkUpdate = ecs.field(it, components.block.ChunkUpdate, 1) orelse continue;
            const updated_index = updateChunk(
                world,
                entity,
                &updated_chunks,
                cu[i],
            ) catch |e| std.debug.panic("highlight block failed: {}\n", .{e});
            if (updated_index >= @as(isize, 9)) has_reached_max_chunks = true;
        }
    }
    // Start refresh jobs for changed chunks.
    for (updated_chunks) |maybe_wp| {
        if (maybe_wp) |wp| {
            // Check if we need to create or refresh the chunk by checking if it has an id in world_chunk_table_data.
            const ch_cfg = game.state.ui.data.world_chunk_table_data.get(wp) orelse std.debug.panic(
                "expected refreshed chunk to be in chunk table. {}",
                .{wp},
            );
            if (ch_cfg.id == 0) {
                // Haven't previously rendered this chunk.
                _ = game.state.jobs.copyChunk(
                    wp,
                    ecs.new_id(game.state.world),
                    false,
                    true,
                );
                continue;
            }
            const c = game.state.gfx.game_chunks.get(wp) orelse std.debug.panic(
                "expected chunk at this point\n",
                .{},
            );
            c.refreshRender(world);
            continue;
        }
        // Got a null, all done.
        break;
    }
}

fn updateChunk(
    world: *ecs.world_t,
    entity: ecs.entity_t,
    updated_chunks: *[10]?chunk.worldPosition,
    cu: components.block.ChunkUpdate,
) !isize {
    const wp = chunk.setBlockId(cu.pos, cu.block_id);
    var update_at: isize = -1;
    for (updated_chunks, 0..) |maybe_wp, i| {
        const f_wp = maybe_wp orelse {
            // Wasn't previously present, so add here.
            update_at = @intCast(i);
            break;
        };
        if (f_wp.equal(wp)) {
            update_at = @intCast(i);
            break;
        }
    }
    if (update_at < 0) return update_at;
    updated_chunks[@intCast(update_at)] = wp;
    ecs.delete(world, entity);
    return update_at;
}
