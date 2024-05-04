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
    pub fn isBrighterThan(self: BlockLighingLevel, r: BlockLighingLevel) bool {
        const sv = @intFromEnum(self);
        const rv = @intFromEnum(r);
        return sv < rv;
    }

    pub fn getNextDarker(self: BlockLighingLevel) BlockLighingLevel {
        if (self == .none) return self;
        return @enumFromInt(@intFromEnum(self) + 1);
    }
};

pub const BlockSurface = enum {
    x_pos,
    x_neg,
    y_pos,
    y_neg,
    z_pos,
    z_neg,
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

    pub fn setFullLighting(self: *BlockData, level: BlockLighingLevel) void {
        self.lighting = switch (level) {
            .full => 0xFFF,
            .bright => 0x0FF,
            .dark => 0x00F,
            .none => 0x000,
        };
    }

    pub fn getFullLighting(self: BlockData) BlockLighingLevel {
        switch (self.lighting) {
            0xFFF => return .full,
            0x0FF => return .bright,
            0x00F => return .dark,
            else => return .none,
        }
    }

    pub fn setSettingsAmbient(self: *BlockData) void {
        self.ambient = 0xFFF;
    }

    pub fn setAmbient(self: *BlockData, surface: BlockSurface, level: BlockLighingLevel) void {
        self.ambient = self.setLightValue(self.ambient, surface, level);
    }

    pub fn setLighting(self: *BlockData, surface: BlockSurface, level: BlockLighingLevel) void {
        self.lighting = self.setLightValue(self.lighting, surface, level);
    }

    pub fn setLightValue(_: *BlockData, light: u12, surface: BlockSurface, level: BlockLighingLevel) u12 {
        var l: u12 = switch (level) {
            .full => 0x03,
            .bright => 0x02,
            .dark => 0x01,
            .none => 0x00,
        };
        var c: u12 = 0x03; // clear bits
        switch (surface) {
            .x_pos => {
                c = c << 10;
                l = l << 10;
            },
            .x_neg => {
                c = c << 8;
                l = l << 8;
            },
            .y_pos => {
                c = c << 6;
                l = l << 6;
            },
            .y_neg => {
                c = c << 4;
                l = l << 4;
            },
            .z_pos => {
                c = c << 2;
                l = l << 2;
            },
            .z_neg => {},
        }
        const clear: u12 = 0xFFF ^ c;
        const lo: u12 = light & clear;
        return lo | l;
    }

    pub fn getSurfaceAmbience(self: *const BlockData, surface: BlockSurface) BlockLighingLevel {
        return self.getLightValue(self.ambient, surface);
    }

    pub fn getSurfaceLighting(self: *const BlockData, surface: BlockSurface) BlockLighingLevel {
        return self.getLightValue(self.lighting, surface);
    }

    pub fn getLightValue(_: *const BlockData, light: u12, surface: BlockSurface) BlockLighingLevel {
        var val: u12 = 0;
        switch (surface) {
            .x_pos => {
                val = light >> 10;
            },
            .x_neg => {
                val = (light | 0xC00) ^ (0xFFF - 0x300);
                val = val >> 8;
            },
            .y_pos => {
                val = light & 0x0F0;
                val = val >> 6;
            },
            .y_neg => {
                val = ((light | 0x0C0) & 0x0F0) ^ (0x0F0 - 0x030);
                val = val >> 4;
            },
            .z_pos => {
                val = light & 0x00F;
                val = val >> 2;
            },
            .z_neg => {
                val = (light | 0x00C) & 0x003;
            },
        }
        switch (val) {
            0x03 => return .full,
            0x02 => return .bright,
            0x01 => return .dark,
            else => return .none,
        }
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
    selected_block: u8 = 12,
};

test "test fromId" {
    const block_id: u32 = 1;
    const bd: BlockData = BlockData.fromId(block_id);
    try std.testing.expectEqual(block_id, bd.block_id);
}

test "test lighting surfaces works" {
    // TODO: test all of these
    const block_id: u32 = 1;
    var ll: BlockLighingLevel = .full;
    var bd: BlockData = BlockData.fromId(block_id);
    bd.setAmbient(.y_neg, ll);
    try std.testing.expectEqual(ll, bd.getSurfaceAmbience(.y_neg));
    ll = .bright;
    bd.setAmbient(.y_neg, ll);
    try std.testing.expectEqual(ll, bd.getSurfaceAmbience(.y_neg));
    ll = .full;
    bd.setAmbient(.z_neg, ll);
    try std.testing.expectEqual(ll, bd.getSurfaceAmbience(.z_neg));
    ll = .bright;
    bd.setAmbient(.z_neg, ll);
    try std.testing.expectEqual(ll, bd.getSurfaceAmbience(.z_neg));

    var bd2: BlockData = BlockData.fromId(block_id);
    bd2.setAmbient(.z_pos, ll);
    try std.testing.expectEqual(ll, bd2.getSurfaceAmbience(.z_pos));
    ll = .bright;
    bd2.setAmbient(.z_pos, ll);
    try std.testing.expectEqual(ll, bd2.getSurfaceAmbience(.z_pos));
}

test "fully lighting lights works" {
    const block_id: u32 = 12;
    var bd: BlockData = BlockData.fromId(block_id);
    bd.setFullLighting(.full);
    try std.testing.expectEqual(.full, bd.getFullLighting());
}

const std = @import("std");
const data = @import("../data/data.zig");

pub const chunk = @import("chunk.zig");
pub const big = @import("block_big.zig");
pub const compress = @import("chunk_compress.zig");
