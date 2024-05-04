// represented by a u64
pub const BlockData = packed struct {
    block_id: u9, // 9 512 values for 512 different block types
    ambient: u12, // 21 ambient light
    lighting: u12, // 33 lamp light
    dim: u1, // 34 any light nearby
    translucent: u1, // 35 spreads light
    orientation: u3, // 38 which way up is
    rotation: u2, // 40 which way block is rotated
    health: u4, // 44 block remembers how damaged it is
    adornment: u20, // 64 20 extra bits of data depending on block type
    pub fn fromId(id: u64) BlockData {
        const bytes: []align(4) const u8 = std.mem.sliceAsBytes(([_]u64{id})[0..]);
        return std.mem.bytesToValue(BlockData, bytes);
    }
    pub fn toId(self: BlockData) u64 {
        const bytes: []align(4) const u8 = std.mem.sliceAsBytes(([_]BlockData{self})[0..]);
        return std.mem.bytesToValue(u64, bytes);
    }
};

const std = @import("std");
