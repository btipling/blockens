const current_format_version: u8 = 0;

data: compressorData = .{
    .format_version = current_format_version,
},
top_chunk: [chunk.chunkSize]u32 = undefined,
bottom_chunk: [chunk.chunkSize]u32 = undefined,
allocator: std.mem.Allocator,

const Compressor = @This();
const chunk_byte_size: usize = chunk.chunkSize * @sizeOf(u32);

const compressorData = packed struct {
    format_version: u8 = 0,
    padding: u56 = 0, // reserved for later and u32 alignment
};

pub fn init(allocator: std.mem.Allocator, top_chunk: []u32, bottom_chunk: []u32) Compressor {
    var c: Compressor = .{
        .allocator = allocator,
    };
    @memcpy(&c.top_chunk, top_chunk);
    @memcpy(&c.bottom_chunk, bottom_chunk);
    return c;
}

fn initFromBytes(allocator: std.mem.Allocator, buffer: []const u8) Compressor {
    var c: Compressor = .{
        .allocator = allocator,
    };
    var i: usize = @sizeOf(compressorData);
    const data_bytes: []const u8 = buffer[0..i];
    const top_chunk_bytes: []const u8 = buffer[i .. i + chunk_byte_size];
    i += chunk_byte_size;
    const bottom_chunk_bytes: []const u8 = buffer[i .. i + chunk_byte_size];
    c.data = std.mem.bytesToValue(compressorData, data_bytes);
    c.top_chunk = std.mem.bytesToValue([chunk.chunkSize]u32, top_chunk_bytes);
    c.bottom_chunk = std.mem.bytesToValue([chunk.chunkSize]u32, bottom_chunk_bytes);
    return c;
}

// caller owns bytes
fn toBytes(self: Compressor) []const u8 {
    const data_bytes: []align(4) const u8 = std.mem.sliceAsBytes(([_]compressorData{self.data})[0..]);
    const top_chunk_bytes: []align(4) const u8 = std.mem.sliceAsBytes(self.top_chunk[0..]);
    const bottom_chunk_bytes: []align(4) const u8 = std.mem.sliceAsBytes(self.bottom_chunk[0..]);
    return std.mem.concat(self.allocator, u8, &[_][]const u8{
        data_bytes,
        top_chunk_bytes,
        bottom_chunk_bytes,
    }) catch @panic("OOM");
}

test "toBytes and initFromBytes" {
    const b1_block_id: u9 = 2;
    const b2_block_id: u9 = 3;
    const bb1_loc: usize = 101;
    const bb2_loc: usize = 202;
    const bb1: block.BlockData = block.BlockData.fromId(b1_block_id);
    const bb2: block.BlockData = block.BlockData.fromId(b2_block_id);
    var top_chunk: [chunk.chunkSize]u32 = std.mem.zeroes([chunk.chunkSize]u32);
    var bottom_chunk: [chunk.chunkSize]u32 = std.mem.zeroes([chunk.chunkSize]u32);
    top_chunk[bb1_loc] = bb1.toId();
    bottom_chunk[bb2_loc] = bb2.toId();
    const c1: Compressor = init(std.testing.allocator, top_chunk[0..], bottom_chunk[0..]);
    const buffer = c1.toBytes();
    defer std.testing.allocator.free(buffer);
    const c2: Compressor = initFromBytes(std.testing.allocator, buffer);
    const retrieved_bb1: block.BlockData = block.BlockData.fromId(c2.top_chunk[bb1_loc]);
    const retrieved_bb2: block.BlockData = block.BlockData.fromId(c2.bottom_chunk[bb2_loc]);
    try std.testing.expectEqual(b1_block_id, retrieved_bb1.block_id);
    try std.testing.expectEqual(b2_block_id, retrieved_bb2.block_id);
}

const std = @import("std");
const chunk = @import("chunk.zig");
const block = @import("block.zig");
