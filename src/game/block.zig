const std = @import("std");
const chunk = @import("chunk.zig");
const data = @import("data/data.zig");

var blocks: *Blocks = undefined;

pub const Block = struct {
    id: u8,
    data: data.block,
};

pub const BlockData = packed struct {
    block_id: u8,
    data: u8,
    lighting: u6,
    ambient: u6,
    direction: u4,
    pub fn fromId(id: u32) BlockData {
        const bytes: []align(4) const u8 = std.mem.sliceAsBytes(([_]u32{id})[0..]);
        return std.mem.bytesToValue(BlockData, bytes);
    }
    pub fn toId(self: BlockData) u32 {
        const bytes: []u8 = std.mem.sliceAsBytes(([_]BlockData{self})[0..]);
        return std.mem.bytesToValue(u32, bytes);
    }
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
