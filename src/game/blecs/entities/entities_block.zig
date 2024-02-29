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
    const world = game.state.world;
    var block_data: data.block = .{};
    game.state.db.loadBlock(legacy_block_id, &block_data) catch unreachable;
    // Each block for the game gets an instances references to draw instanced versions of the block type in the world.
    // those are for blocks that weren't meshed, to avoid extra draw calls.
    // The settings views block instances aren't stored this way as they are view only and are cleared on every
    // render of the settings page.
    const block_entity = helpers.new_child(world, entities_screen.game_data);
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
    _ = ecs.set(world, block_entity, components.block.Block, .{
        .block_id = block_id,
    });
    // The block is set up to draw instances
    ecs.add(world, block_entity, components.block.BlockInstances);
    _ = ecs.set(world, block_entity, components.shape.Shape, .{ .shape_type = .cube });
    ecs.add(world, block_entity, components.shape.NeedsSetup);
}

pub fn deinitBlock(block_id: u8) void {
    const world = game.state.world;
    if (game.state.blocks.get(block_id)) |b| {
        ecs.add(world, b.entity_id, components.gfx.NeedsDeletion);
        game.state.allocator.free(b.data.texture);
        game.state.allocator.destroy(b);
    }
}
