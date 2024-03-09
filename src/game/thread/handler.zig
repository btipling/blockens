const std = @import("std");
const game = @import("../game.zig");
const blecs = @import("../blecs/blecs.zig");
const chunk = @import("../chunk.zig");
const buffer = @import("./buffer.zig");

var handler: *Handler = undefined;

const Handler = struct {};

pub fn init() void {
    handler = game.state.allocator.create(Handler);
    handler.* = .{};
}

pub fn deinit() void {
    game.state.allocator.destroy(handler);
}

pub fn handle_incomming() void {
    if (!buffer.has_message()) return;
    const msg = buffer.next_message() orelse return;
    switch (msg.type) {
        .chunk_gen => handle_chunk_gen(msg),
        .chunk_mesh => handle_chunk_mesh(msg),
    }
}

fn handle_chunk_gen(msg: buffer.buffer_message) void {
    if (!buffer.progress_report(msg).done) return;
    if (buffer.is_demo_chunk(msg)) return handle_demo_chunk_gen(msg);
}

fn handle_demo_chunk_gen(msg: buffer.buffer_message) void {
    if (!buffer.progress_report(msg).done) return;
    const chunk_data = buffer.get_chunk_gen_data(msg).?;
    if (game.state.ui.data.chunk_demo_data) |d| game.state.allocator.free(d);
    game.state.ui.data.chunk_demo_data = chunk_data;
    blecs.ecs.add(game.state.world, game.state.entities.screen, blecs.components.screen.NeedsDemoChunk);
}

fn handle_chunk_mesh(msg: buffer.buffer_message) void {
    if (!buffer.progress_report(msg).done) return;
}
