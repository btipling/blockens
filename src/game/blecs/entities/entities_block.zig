const std = @import("std");
const ecs = @import("zflecs");
const game = @import("../../game.zig");
const game_state = @import("../../state/game.zig");
const data = @import("../../data/data.zig");
const components = @import("../components/components.zig");
const helpers = @import("../helpers.zig");
const entities_screen = @import("entities_screen.zig");

pub fn init() void {
    initBlocks();
}

pub fn initBlocks() void {
    std.debug.print("init block entities\n", .{});
    for (game.state.ui.data.block_options.items) |o| {
        const block_id: u8 = @intCast(o.id);
        initBlock(block_id);
    }
}

pub fn deinitBlocks() void {
    std.debug.print("deinit block entities\n", .{});
    for (game.state.ui.data.block_options.items) |o| {
        const block_id: u8 = @intCast(o.id);
        deinitBlock(block_id);
    }
}

pub fn initBlock(block_id: u8) void {
    const legacy_block_id: i32 = @intCast(block_id);
    var block_data: data.block = .{};
    game.state.db.loadBlock(legacy_block_id, &block_data) catch unreachable;
    // Each block for the game gets an instances references to draw instanced versions of the block type in the world.
    // those are for blocks that weren't meshed, to avoid extra draw calls.
    // The settings views block instances aren't stored this way as they are view only and are cleared on every
    // render of the settings page.
    const block: *game_state.Block = game.state.allocator.create(game_state.Block) catch unreachable;
    block.* = .{
        .id = block_id,
        .data = block_data,
    };
    if (game.state.gfx.blocks.get(block_id)) |b| {
        game.state.allocator.free(b.data.texture);
        game.state.allocator.destroy(b);
    }
    game.state.gfx.blocks.put(block_id, block) catch unreachable;
}

pub fn deinitBlock(block_id: u8) void {
    if (game.state.gfx.blocks.get(block_id)) |b| {
        game.state.allocator.free(b.data.texture);
        game.state.allocator.destroy(b);
    }
}