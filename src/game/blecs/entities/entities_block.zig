const std = @import("std");
const ecs = @import("zflecs");
const game = @import("../../game.zig");
const gfx = @import("../../gfx/gfx.zig");
const data = @import("../../data/data.zig");
const block = @import("../../block.zig");
const components = @import("../components/components.zig");
const helpers = @import("../helpers.zig");
const entities_screen = @import("entities_screen.zig");

pub var HasChunkRenderer: ecs.entity_t = 0;

pub const MaxBlocks = 256;

pub fn init() void {
    HasChunkRenderer = ecs.new_id(game.state.world);
    initBlocks();
}

pub fn initBlocks() void {
    std.debug.print("init block entities\n", .{});
    for (game.state.ui.data.block_options.items) |o| {
        const block_id: u8 = @intCast(o.id);
        initBlock(block_id);
    }
    loadTextureAtlas();
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
    const b: *block.Block = game.state.allocator.create(block.Block) catch unreachable;
    b.* = .{
        .id = block_id,
        .data = block_data,
    };
    if (game.state.blocks.blocks.get(block_id)) |_b| {
        game.state.allocator.free(_b.data.texture);
        game.state.allocator.destroy(_b);
    }
    game.state.blocks.blocks.put(block_id, b) catch unreachable;
    loadTextureAtlas();
}

pub fn deinitBlock(block_id: u8) void {
    if (game.state.blocks.blocks.get(block_id)) |b| {
        game.state.allocator.free(b.data.texture);
        game.state.allocator.destroy(b);
    }
}

pub fn loadTextureAtlas() void {
    var ta = std.ArrayList(u32).init(game.state.allocator);
    defer ta.deinit();
    game.state.ui.data.texture_atlas_block_index = [_]usize{0} ** MaxBlocks;
    var it = game.state.blocks.blocks.valueIterator();
    var i: usize = 0;
    while (it.next()) |_b| {
        const b = _b.*;
        ta.appendSlice(b.data.texture) catch unreachable;
        game.state.ui.data.texture_atlas_block_index[@intCast(b.id)] = i;
        i += 1;
    }
    game.state.ui.data.texture_atlas_num_blocks = i;
    if (game.state.ui.data.texture_atlas_rgba_data) |d| game.state.allocator.free(d);
    game.state.ui.data.texture_atlas_rgba_data = ta.toOwnedSlice() catch unreachable;
}
