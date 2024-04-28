const current_format_version: u8 = 0;

data: compressorData = .{
    .format_version = current_format_version,
},
chunk_data: [chunk.chunkSize]u64 = undefined,
allocator: std.mem.Allocator,

const Compressor = @This();
const big_chunk_byte_size: usize = chunk.chunkSize * @sizeOf(u64);

const compressorData = packed struct {
    format_version: u8 = 0,
    padding: u56 = 0, // reserved for later and u64 alignment
};

pub fn init(allocator: std.mem.Allocator, chunk_bytes: []u64) Compressor {
    var c: Compressor = .{
        .allocator = allocator,
    };
    @memcpy(&c.chunk_data, chunk_bytes);
    return c;
}

fn initFromBytes(allocator: std.mem.Allocator, buffer: []const u8) Compressor {
    var c: Compressor = .{
        .allocator = allocator,
    };
    const i: usize = @sizeOf(compressorData);
    const data_bytes: []const u8 = buffer[0..i];
    const chunk_bytes: []const u8 = buffer[i .. i + big_chunk_byte_size];
    c.data = std.mem.bytesToValue(compressorData, data_bytes);
    c.chunk_data = std.mem.bytesToValue([chunk.chunkSize]u64, chunk_bytes);
    return c;
}

// caller owns bytes
fn toBytes(self: Compressor) []const u8 {
    const data_bytes: []align(4) const u8 = std.mem.sliceAsBytes(([_]compressorData{self.data})[0..]);
    const chunk_bytes: []align(4) const u8 = std.mem.sliceAsBytes(self.chunk_data[0..]);
    return std.mem.concat(self.allocator, u8, &[_][]const u8{
        data_bytes,
        chunk_bytes,
    }) catch @panic("OOM");
}

test "toBytes and initFromBytes" {
    const b1_block_id: u9 = 2;
    const bb1_loc: usize = 101;
    const bb1: BigBlock.BlockData = BigBlock.BlockData.fromId(b1_block_id);
    var chunk_data: [chunk.chunkSize]u64 = std.mem.zeroes([chunk.chunkSize]u64);
    chunk_data[bb1_loc] = bb1.toId();
    const c1: Compressor = init(std.testing.allocator, chunk_data[0..]);
    const buffer = c1.toBytes();
    defer std.testing.allocator.free(buffer);
    const c2: Compressor = initFromBytes(std.testing.allocator, buffer);
    const retrieved_bb1: BigBlock.BlockData = BigBlock.BlockData.fromId(c2.chunk_data[bb1_loc]);
    try std.testing.expectEqual(b1_block_id, retrieved_bb1.block_id);
}

const std = @import("std");
const chunk = @import("chunk.zig");
const block = @import("block.zig");
const BigBlock = block.big;
