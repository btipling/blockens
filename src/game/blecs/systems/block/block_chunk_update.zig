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

            const wp = chunk.worldPosition.getWorldPositionForWorldLocation(cu[i].pos);
            if (game.state.blocks.game_chunks.get(wp)) |c| {
                if (ecs.is_alive(world, c.entity) and ecs.has_id(world, c.entity, ecs.id(components.gfx.HasPreviousRenderer))) continue;
            }
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
            const c = game.state.blocks.game_chunks.get(wp) orelse std.debug.panic(
                "expected chunk at this point\n",
                .{},
            );
            if (config.use_tracy) ztracy.MessageC("refresh rendering chunk", 0xFF0000);
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
    const wp = chunk.worldPosition.getWorldPositionForWorldLocation(cu.pos);
    if (game.state.blocks.game_chunks.get(wp) == null) {
        chunk.createEditedChunk(wp, cu.pos, cu.block_id);
        ecs.delete(world, entity);
        return -1;
    }
    _ = chunk.setBlockId(cu.pos, cu.block_id) orelse return -1;
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

const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const block = @import("../../../block/block.zig");
const chunk = block.chunk;
