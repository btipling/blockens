const std = @import("std");
const chunk = @import("chunk.zig");
const data = @import("data/data.zig");

var blocks: *Blocks = undefined;

pub const Block = struct {
    id: u8,
    data: data.block,
};

pub fn init(allocator: std.mem.Allocator) *Blocks {
    blocks = allocator.create(Blocks) catch @panic("OMM");
    blocks.* = .{
        .blocks = std.AutoHashMap(u8, *Block).init(allocator),
        .settings_chunks = std.AutoHashMap(chunk.worldPosition, *chunk.Chunk).init(allocator),
        .game_chunks = std.AutoHashMap(chunk.worldPosition, *chunk.Chunk).init(allocator),
    };
    return blocks;
}

pub fn deinit(allocator: std.mem.Allocator) void {
    var bs = blocks.blocks.valueIterator();
    while (bs.next()) |b| {
        allocator.free(b.*.data.texture);
        allocator.destroy(b.*);
    }
    blocks.blocks.deinit();
    var sc_i = blocks.settings_chunks.valueIterator();
    while (sc_i.next()) |ce| {
        ce.*.deinit();
        allocator.destroy(ce.*);
    }
    blocks.settings_chunks.deinit();
    var gc_i = blocks.game_chunks.valueIterator();
    while (gc_i.next()) |ce| {
        ce.*.deinit();
        allocator.destroy(ce.*);
    }
    blocks.game_chunks.deinit();
    allocator.destroy(blocks);
}

pub const Blocks = struct {
    blocks: std.AutoHashMap(u8, *Block) = undefined,
    game_chunks: std.AutoHashMap(chunk.worldPosition, *chunk.Chunk) = undefined,
    settings_chunks: std.AutoHashMap(chunk.worldPosition, *chunk.Chunk) = undefined,
    selected_block: u8 = 4,
};
