const std = @import("std");
const game = @import("../game.zig");
const blecs = @import("../blecs/blecs.zig");
const chunk = @import("../chunk.zig");
const buffer = @import("./buffer.zig");
const helpers = @import("../blecs/helpers.zig");

var handler: *Handler = undefined;

const Handler = struct {};

const maxHandlersPerFrame = 1000;

pub fn init() !void {
    handler = try game.state.allocator.create(Handler);
    handler.* = .{};
}

pub fn deinit() void {
    game.state.allocator.destroy(handler);
}

pub fn handle_incoming() !void {
    var i: u32 = 0;
    while (buffer.next_message()) |msg| {
        switch (msg.type) {
            .chunk_gen => try handle_chunk_gen(msg),
            .chunk_mesh => handle_chunk_mesh(msg),
            .chunk_copy => handle_copy_chunk(msg),
        }
        i += 0;
        if (i >= maxHandlersPerFrame) return;
    }
}

fn handle_chunk_gen(msg: buffer.buffer_message) !void {
    if (!buffer.progress_report(msg).done) return;
    if (try buffer.is_demo_chunk(msg)) return handle_demo_chunk_gen(msg);
    const chunk_data = buffer.get_chunk_gen_data(msg).?;
    const wp = chunk_data.wp orelse return;

    var ch_cfg = game.state.ui.data.world_chunk_table_data.get(wp) orelse {
        std.debug.panic("handled chunk gen for non existent chunk in chunk table\n", .{});
    };
    ch_cfg.chunkData = chunk_data.chunk_data;
    if (game.state.ui.data.world_chunk_table_data.get(wp)) |cd| {
        game.state.allocator.free(cd.chunkData);
    }
    game.state.ui.data.world_chunk_table_data.put(wp, ch_cfg) catch @panic("OOM");
}

fn handle_demo_chunk_gen(msg: buffer.buffer_message) void {
    if (!buffer.progress_report(msg).done) return;
    const chunk_data = buffer.get_chunk_gen_data(msg).?;
    if (game.state.ui.data.chunk_demo_data) |d| game.state.allocator.free(d);
    game.state.ui.data.chunk_demo_data = chunk_data.chunk_data;
    blecs.ecs.add(
        game.state.world,
        game.state.entities.screen,
        blecs.components.screen.NeedsDemoChunk,
    );
}

fn handle_chunk_mesh(msg: buffer.buffer_message) void {
    if (!buffer.progress_report(msg).done) return;
    const mesh_data = buffer.get_chunk_mesh_data(msg) orelse return;
    const world = mesh_data.world orelse return;
    const entity = mesh_data.entity orelse return;
    if (mesh_data.empty) {
        if (blecs.ecs.has_id(world, entity, blecs.ecs.id(blecs.components.gfx.ElementsRenderer))) {
            blecs.ecs.add(world, entity, blecs.components.gfx.NeedsDeletion);
        }
        return;
    }
    if (entity != 0 and blecs.ecs.is_alive(world, entity)) {
        blecs.ecs.add(world, entity, blecs.components.block.NeedsMeshRendering);
        return;
    }
    const chunk_entity = init_chunk_entity(world, mesh_data.chunk);
    blecs.ecs.add(world, chunk_entity, blecs.components.block.NeedsMeshRendering);
}

fn handle_copy_chunk(msg: buffer.buffer_message) void {
    if (!buffer.progress_report(msg).done) return;
    const world = game.state.world;
    const copy_data = buffer.get_chunk_copy_data(msg) orelse return;
    const chunk_entity = init_chunk_entity(world, copy_data.chunk);

    blecs.ecs.add(world, chunk_entity, blecs.components.block.NeedsMeshing);

    const wp = copy_data.chunk.wp;
    if (copy_data.chunk.is_settings) {
        if (game.state.blocks.settings_chunks.get(wp)) |c| {
            c.deinit();
            game.state.allocator.destroy(c);
        }
        game.state.blocks.settings_chunks.put(wp, copy_data.chunk) catch @panic("OOM");
    } else {
        if (game.state.blocks.game_chunks.get(wp)) |c| {
            c.deinit();
            game.state.allocator.destroy(c);
        }
        game.state.blocks.game_chunks.put(wp, copy_data.chunk) catch @panic("OOM");
    }
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
