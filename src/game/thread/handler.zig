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
    while (buffer.has_message()) {
        const msg = buffer.next_message() orelse return;
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

    var ch_cfg = game.state.ui.data.world_chunk_table_data.get(wp) orelse return;
    ch_cfg.chunkData = chunk_data.chunk_data;
    if (game.state.ui.data.world_chunk_table_data.get(wp)) |cd| {
        game.state.allocator.free(cd.chunkData);
    }
    game.state.ui.data.world_chunk_table_data.put(wp, ch_cfg) catch unreachable;
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
    blecs.ecs.add(world, entity, blecs.components.block.NeedsMeshRendering);
}

fn handle_copy_chunk(msg: buffer.buffer_message) void {
    if (!buffer.progress_report(msg).done) return;
    const copy_data = buffer.get_chunk_copy_data(msg) orelse return;
    const wp = copy_data.chunk.wp;
    const p = wp.vecFromWorldPosition();
    const world = game.state.world;
    var chunk_entity: blecs.ecs.entity_t = 0;
    if (copy_data.chunk.is_settings) {
        chunk_entity = helpers.new_child(world, blecs.entities.screen.settings_data);
    } else {
        chunk_entity = helpers.new_child(world, blecs.entities.screen.game_data);
    }

    blecs.ecs.add_pair(
        world,
        copy_data.chunk.entity,
        blecs.entities.block.HasChunkRenderer,
        chunk_entity,
    );
    var loc: @Vector(4, f32) = undefined;
    if (copy_data.chunk.is_settings) {
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
    blecs.ecs.add(world, chunk_entity, blecs.components.block.NeedsMeshing);
    if (copy_data.chunk.is_settings) {
        if (game.state.gfx.settings_chunks.get(wp)) |c| {
            c.deinit();
            game.state.allocator.destroy(c);
        }
        game.state.gfx.settings_chunks.put(wp, copy_data.chunk) catch unreachable;
    } else {
        if (game.state.gfx.game_chunks.get(wp)) |c| {
            c.deinit();
            game.state.allocator.destroy(c);
        }
        game.state.gfx.game_chunks.put(wp, copy_data.chunk) catch unreachable;
    }
}
