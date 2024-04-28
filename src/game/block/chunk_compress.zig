const current_format_version: u8 = 0;

data: compressorData = .{
    .format_version = current_format_version,
},
top_chunk: []u64 = undefined,
bottom_chunk: []u64 = undefined,
allocator: std.mem.Allocator,

const Compressor = @This();
const chunk_byte_size: usize = chunk.chunkSize * @sizeOf(u64);

const compressorData = packed struct {
    format_version: u8 = 0,
    padding: u56 = 0, // reserved for later and u64 alignment
};

pub fn init(allocator: std.mem.Allocator, top_chunk: []u64, bottom_chunk: []u64) *Compressor {
    const c: *Compressor = allocator.create(Compressor) catch @panic("OOM");
    c.* = .{
        .allocator = allocator,
        .top_chunk = allocator.dupe(u64, top_chunk) catch @panic("OOM"),
        .bottom_chunk = allocator.dupe(u64, bottom_chunk) catch @panic("OOM"),
    };
    return c;
}

pub fn deinit(self: *Compressor) void {
    self.allocator.free(self.top_chunk);
    self.allocator.free(self.bottom_chunk);
    self.allocator.destroy(self);
}

fn initFromBytes(allocator: std.mem.Allocator, buffer: []const u8) *Compressor {
    const c: *Compressor = allocator.create(Compressor) catch @panic("OOM");
    c.* = .{
        .allocator = allocator,
    };
    var i: usize = @sizeOf(compressorData);
    const data_bytes: []const u8 = buffer[0..i];
    const top_chunk_bytes: []align(8) const u8 = @alignCast(buffer[i .. i + chunk_byte_size]);
    i += chunk_byte_size;
    const bottom_chunk_bytes: []align(8) const u8 = @alignCast(buffer[i .. i + chunk_byte_size]);
    c.data = std.mem.bytesToValue(compressorData, data_bytes);
    c.top_chunk = allocator.dupe(
        u64,
        std.mem.bytesAsSlice(u64, top_chunk_bytes),
    ) catch @panic("OOM");
    c.bottom_chunk = allocator.dupe(
        u64,
        std.mem.bytesAsSlice(u64, bottom_chunk_bytes),
    ) catch @panic("OOM");
    return c;
}

fn initFromReader(allocator: std.mem.Allocator, reader: anytype) *Compressor {
    const buffer: []u8 = allocator.alloc(
        u8,
        chunk_byte_size + chunk_byte_size + @sizeOf(compressorData),
    ) catch @panic("OOM");
    defer allocator.free(buffer);
    _ = reader.readAll(@ptrCast(buffer)) catch @panic("read all error");
    return initFromBytes(allocator, buffer);
}

// caller owns bytes
fn toBytes(self: *Compressor) []const u8 {
    const data_bytes: []align(4) const u8 = std.mem.sliceAsBytes(([_]compressorData{self.data})[0..]);
    const top_chunk_bytes: []align(4) const u8 = std.mem.sliceAsBytes(self.top_chunk);
    const bottom_chunk_bytes: []align(4) const u8 = std.mem.sliceAsBytes(self.bottom_chunk);
    return std.mem.concat(self.allocator, u8, &[_][]const u8{
        data_bytes,
        top_chunk_bytes,
        bottom_chunk_bytes,
    }) catch @panic("OOM");
}

fn toWriter(self: *Compressor) std.io.FixedBufferStream([]const u8) {
    const buffer = self.toBytes();
    const s: std.io.FixedBufferStream([]const u8) = .{
        .buffer = buffer,
        .pos = 0,
    };
    return s;
}

test "toBytes and initFromBytes" {
    const b1_block_id: u9 = 2;
    const b2_block_id: u9 = 3;
    const bb1_loc: usize = 101;
    const bb2_loc: usize = 202;
    const bb1: BigBlock.BlockData = BigBlock.BlockData.fromId(b1_block_id);
    const bb2: BigBlock.BlockData = BigBlock.BlockData.fromId(b2_block_id);

    var top_chunk: []u64 = std.testing.allocator.dupe(u64, BigChunk.fully_lit_chunk[0..]) catch @panic("OOM");
    defer std.testing.allocator.free(top_chunk);
    var bottom_chunk: []u64 = std.testing.allocator.dupe(u64, BigChunk.fully_lit_chunk[0..]) catch @panic("OOM");
    defer std.testing.allocator.free(bottom_chunk);
    top_chunk[bb1_loc] = bb1.toId();
    bottom_chunk[bb2_loc] = bb2.toId();
    const c1: *Compressor = init(std.testing.allocator, top_chunk[0..], bottom_chunk[0..]);
    defer c1.deinit();
    const buffer = c1.toBytes();
    defer std.testing.allocator.free(buffer);
    const c2: *Compressor = initFromBytes(std.testing.allocator, buffer);
    defer c2.deinit();
    const retrieved_bb1: BigBlock.BlockData = BigBlock.BlockData.fromId(c2.top_chunk[bb1_loc]);
    const retrieved_bb2: BigBlock.BlockData = BigBlock.BlockData.fromId(c2.bottom_chunk[bb2_loc]);
    try std.testing.expectEqual(b1_block_id, retrieved_bb1.block_id);
    try std.testing.expectEqual(b2_block_id, retrieved_bb2.block_id);
}

test "toWriter and initFromReader" {
    const b1_block_id: u9 = 9;
    const b2_block_id: u9 = 13;
    const bb1_loc: usize = 301;
    const bb2_loc: usize = 402;
    const bb1: BigBlock.BlockData = BigBlock.BlockData.fromId(b1_block_id);
    const bb2: BigBlock.BlockData = BigBlock.BlockData.fromId(b2_block_id);
    var top_chunk: []u64 = std.testing.allocator.dupe(u64, BigChunk.fully_lit_chunk[0..]) catch @panic("OOM");
    defer std.testing.allocator.free(top_chunk);
    var bottom_chunk: []u64 = std.testing.allocator.dupe(u64, BigChunk.fully_lit_chunk[0..]) catch @panic("OOM");
    defer std.testing.allocator.free(bottom_chunk);
    top_chunk[bb1_loc] = bb1.toId();
    bottom_chunk[bb2_loc] = bb2.toId();
    const c1: *Compressor = init(std.testing.allocator, top_chunk[0..], bottom_chunk[0..]);
    defer c1.deinit();
    var s = c1.toWriter();
    defer std.testing.allocator.free(s.buffer);
    const c2: *Compressor = initFromReader(std.testing.allocator, s.reader());
    defer c2.deinit();
    const retrieved_bb1: BigBlock.BlockData = BigBlock.BlockData.fromId(c2.top_chunk[bb1_loc]);
    const retrieved_bb2: BigBlock.BlockData = BigBlock.BlockData.fromId(c2.bottom_chunk[bb2_loc]);
    try std.testing.expectEqual(b1_block_id, retrieved_bb1.block_id);
    try std.testing.expectEqual(b2_block_id, retrieved_bb2.block_id);
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
const BigChunk = chunk.big;
const BigBlock = block.big;
