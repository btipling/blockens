const std = @import("std");
const ecs = @import("zflecs");
const game = @import("../../game.zig");
const game_state = @import("../../state/game.zig");
const data = @import("../../data/data.zig");

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
    const world = game.state.world;
    var block_data: data.block = .{};
    game.state.db.loadBlock(legacy_block_id, &block_data) catch unreachable;
    const block_entity = ecs.new_id(world);
    const block: *game_state.Block = game.state.allocator.create(game_state.Block) catch unreachable;
    block.* = .{
        .id = block_id,
        .data = block_data,
        .entity_id = block_entity,
    };
    if (game.state.blocks.get(block_id)) |b| {
        game.state.allocator.free(b.data.texture);
        game.state.allocator.destroy(b);
    }
    game.state.blocks.put(block_id, block) catch unreachable;
    // TODO add block component
    // TODO add block instance shape ya? I think so.
}

pub fn deinitBlock(block_id: u8) void {
    const world = game.state.world;
    if (game.state.blocks.get(block_id)) |b| {
        // TODO clear out block entity shapes and instances, delete with needs deletion
        ecs.delete(world, b.entity_id);
        game.state.allocator.free(b.data.texture);
        game.state.allocator.destroy(b);
    }
}
