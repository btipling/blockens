const std = @import("std");
const game = @import("../game.zig");
const blecs = @import("../blecs/blecs.zig");
const chunk = @import("../chunk.zig");
const buffer = @import("./buffer.zig");

var handler: *Handler = undefined;

const Handler = struct {};

pub fn init() !void {
    handler = try game.state.allocator.create(Handler);
    handler.* = .{};
}

pub fn deinit() void {
    game.state.allocator.destroy(handler);
}

pub fn handle_incoming() !void {
    if (!buffer.has_message()) return;
    const msg = buffer.next_message() orelse return;
    switch (msg.type) {
        .chunk_gen => try handle_chunk_gen(msg),
        .chunk_mesh => handle_chunk_mesh(msg),
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
    blecs.ecs.add(game.state.world, game.state.entities.screen, blecs.components.screen.NeedsDemoChunk);
}

fn handle_chunk_mesh(msg: buffer.buffer_message) void {
    if (!buffer.progress_report(msg).done) return;
    const mesh_data = buffer.get_chunk_mesh_data(msg).?;
    const world = mesh_data.world orelse return;
    const entity = mesh_data.entity orelse return;
    blecs.ecs.add(world, entity, blecs.components.block.NeedsMeshRendering);
}
