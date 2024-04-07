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

    pub fn clearAmbient(self: *BlockData) void {
        self.ambient = 0;
    }

    // Full ambiance is an transparent block thing. Air blocks, and transparent blocks
    // propagate ambiant light.
    pub fn setFullAmbiance(self: *BlockData, level: BlockLighingLevel) void {
        if (self.block_id != 0) return;
        self.ambient = switch (level) {
            .full => 0xFFF,
            .bright => 0x0FF,
            .dark => 0x00F,
            .none => 0x000,
        };
    }

    pub fn getFullAmbiance(self: BlockData) BlockLighingLevel {
        if (self.block_id != 0) return .none;
        switch (self.ambient) {
            0xFFF => return .full,
            0x0FF => return .bright,
            0x00F => return .dark,
            else => return .none,
        }
    }

    pub fn setAmbient(self: *BlockData, surface: BlockSurface, level: BlockLighingLevel) void {
        var l: u12 = switch (level) {
            .full => 0x03,
            .bright => 0x02,
            .dark => 0x01,
            .none => 0x00,
        };
        switch (surface) {
            .top => {
                l = l << 10;
            },
            .bottom => {
                l = l << 8;
            },
            .front => {
                l = l << 6;
            },
            .back => {
                l = l << 4;
            },
            .left => {
                l = l << 2;
            },
            .right => {},
        }
        self.ambient = self.ambient | l;
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
