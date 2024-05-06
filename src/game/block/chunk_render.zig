pub fn renderSettingsChunk(
    wp: chunk.worldPosition,
    entity: blecs.ecs.entity_t,
) void {
    const world = game.state.world;

    var c: *chunk.Chunk = chunk.Chunk.init(
        game.state.allocator,
        wp,
        entity,
        true,
        game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM"),
    ) catch @panic("OOM");
    errdefer c.deinit();

    const entry = game.state.blocks.generated_settings_chunks.fetchRemove(wp) orelse return;
    const data: []u32 = entry.value;
    defer game.state.allocator.free(data);
    @memcpy(c.data, data);

    const chunk_entity = init_chunk_entity(world, c);
    blecs.ecs.add(world, chunk_entity, blecs.components.block.NeedsMeshing);

    if (game.state.blocks.settings_chunks.get(wp)) |cc| {
        cc.deinit();
        game.state.allocator.destroy(cc);
    }
    game.state.blocks.settings_chunks.put(wp, c) catch @panic("OOM");
}

pub fn renderGameChunk(
    wp: chunk.worldPosition,
    entity: blecs.ecs.entity_t,
    save: bool,
) void {
    const world = game.state.world;

    const ch_cfg = game.state.ui.world_chunk_table_data.get(wp) orelse return;
    var c: *chunk.Chunk = chunk.Chunk.init(
        game.state.allocator,
        wp,
        entity,
        false,
        game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM"),
    ) catch @panic("OOM");
    errdefer c.deinit();
    @memcpy(c.data, ch_cfg.chunkData);
    c.updated = true;

    const chunk_entity = init_chunk_entity(world, c);
    blecs.ecs.add(world, chunk_entity, blecs.components.block.NeedsMeshing);

    if (game.state.blocks.game_chunks.get(wp)) |cc| {
        cc.deinit();
        game.state.allocator.destroy(cc);
    }
    game.state.blocks.game_chunks.put(wp, c) catch @panic("OOM");

    if (!save) return;
    game.state.jobs.save_updated_chunks();
}

fn init_chunk_entity(world: *blecs.ecs.world_t, c: *chunk.Chunk) blecs.ecs.entity_t {
    const wp = c.wp;
    const p = wp.vecFromWorldPosition();
    var chunk_entity: blecs.ecs.entity_t = 0;
    if (c.is_settings) {
        chunk_entity = helpers.new_child(world, blecs.entities.screen.settings_data);
    } else {
        chunk_entity = helpers.new_child(world, blecs.entities.screen.game_data);
    }

    blecs.ecs.add_pair(
        world,
        c.entity,
        blecs.entities.block.HasChunkRenderer,
        chunk_entity,
    );
    var loc: @Vector(4, f32) = undefined;
    if (c.is_settings) {
        loc = .{ -32, 0, -32, 0 };
    } else {
        loc = .{
            p[0] * chunk.chunkDim,
            p[1] * chunk.chunkDim,
            p[2] * chunk.chunkDim,
            0,
        };
    }
    _ = blecs.ecs.set(world, chunk_entity, blecs.components.block.Chunk, .{
        .loc = loc,
        .wp = wp,
    });
    blecs.ecs.add(world, chunk_entity, blecs.components.block.UseMultiDraw);
    return chunk_entity;
}
const helpers = @import("../blecs/helpers.zig");

const blecs = @import("../blecs/blecs.zig");
const chunk = @import("chunk.zig");
const game = @import("../game.zig");
