const std = @import("std");
const chunk = @import("chunk.zig");
const data = @import("data/data.zig");

var blocks: *Blocks = undefined;

pub const Block = struct {
    id: u8,
    data: data.block,
};

pub const BlockLighingLevel = enum {
    full,
    bright,
    dark,
    none,
};

pub const BlockSurface = enum {
    top,
    bottom,
    front,
    back,
    left,
    right,
};

pub const BlockData = packed struct {
    block_id: u8,
    ambient: u12,
    lighting: u12,
    pub fn fromId(id: u32) BlockData {
        const bytes: []align(4) const u8 = std.mem.sliceAsBytes(([_]u32{id})[0..]);
        return std.mem.bytesToValue(BlockData, bytes);
    }
    pub fn toId(self: BlockData) u32 {
        const bytes: []align(4) const u8 = std.mem.sliceAsBytes(([_]BlockData{self})[0..]);
        return std.mem.bytesToValue(u32, bytes);
    }
    pub fn setAmbient(self: *BlockData, surface: BlockSurface, level: BlockLighingLevel) void {
        var current = self.ambient;
        var l: u12 = switch (level) {
            .full => 0x03,
            .bright => 0x02,
            .dark => 0x01,
            .none => 0x00,
        };
        switch (surface) {
            .top => {
                l = l << 10;
                current ^= 0xC00;
            },
            .bottom => {
                l = l << 8;
                current ^= 0x300;
            },
            .front => {
                l = l << 6;
                current ^= 0x0C0;
            },
            .back => {
                l = l << 4;
                current ^= 0x030;
            },
            .left => {
                l = l << 2;
                current ^= 0x00C;
            },
            .right => {
                current ^= 0x003;
            },
        }
        self.ambient = current | l;
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
