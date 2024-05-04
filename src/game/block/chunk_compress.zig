const current_format_version: u8 = 0;

data: compressorData = .{
    .format_version = current_format_version,
},
top_chunk: []u64 = undefined,
bottom_chunk: []u64 = undefined,
allocator: std.mem.Allocator,

const Compress = @This();
const chunk_byte_size: usize = chunk.chunkSize * @sizeOf(u64);

const compressorData = packed struct {
    format_version: u8 = 0,
    padding: u56 = 0, // reserved for later and u64 alignment
};

pub fn init(allocator: std.mem.Allocator, top_chunk: []u64, bottom_chunk: []u64) *Compress {
    const c: *Compress = allocator.create(Compress) catch @panic("OOM");
    c.* = .{
        .allocator = allocator,
        .top_chunk = allocator.dupe(u64, top_chunk) catch @panic("OOM"),
        .bottom_chunk = allocator.dupe(u64, bottom_chunk) catch @panic("OOM"),
    };
    return c;
}

pub fn deinit(self: *Compress) void {
    self.allocator.free(self.top_chunk);
    self.allocator.free(self.bottom_chunk);
    self.allocator.destroy(self);
}

pub fn initFromCompressed(allocator: std.mem.Allocator, reader: anytype) !*Compress {
    // Create bufer to read decompressed bits into
    const needed_space: usize = @sizeOf(compressorData) + chunk.chunkSize * @sizeOf(u64) * 2;
    const buffer: []u8 = allocator.alloc(u8, needed_space) catch @panic("OOM");
    defer allocator.free(buffer);

    // Decompress the bits into the buffer
    var fbs = std.io.fixedBufferStream(buffer);
    std.compress.gzip.decompress(reader, fbs.writer()) catch |err| {
        if (err == error.EndOfStream) {
            std.debug.print("EOS bytes written: fbs {d}\n", .{fbs.pos});
        }
        return err;
    };

    // Create a compressor instance
    const c: *Compress = allocator.create(Compress) catch @panic("OOM");
    c.* = .{
        .allocator = allocator,
    };

    // Convert buffer to compressor data
    var i: usize = @sizeOf(compressorData);

    // First the header
    const data_bytes: []const u8 = buffer[0..i];
    c.data = std.mem.bytesToValue(compressorData, data_bytes);

    // Top chunk bits
    const top_chunk_bytes: []align(8) const u8 = @alignCast(buffer[i .. i + chunk_byte_size]);
    // Dupe the bits to deallocate separately
    c.top_chunk = allocator.dupe(
        u64,
        std.mem.bytesAsSlice(u64, top_chunk_bytes),
    ) catch @panic("OOM");

    // Bottom chunk bits
    i += chunk_byte_size;
    const bottom_chunk_bytes: []align(8) const u8 = @alignCast(buffer[i .. i + chunk_byte_size]);
    // Dupe these too
    c.bottom_chunk = allocator.dupe(
        u64,
        std.mem.bytesAsSlice(u64, bottom_chunk_bytes),
    ) catch @panic("OOM");

    return c;
}

pub fn compress(self: *Compress, writer: anytype) !void {
    // Setup the data to compress

    // Convert all the props to bits
    const data_bytes: []align(4) const u8 = std.mem.sliceAsBytes(([_]compressorData{self.data})[0..]);
    const top_chunk_bytes: []align(4) const u8 = std.mem.sliceAsBytes(self.top_chunk);
    const bottom_chunk_bytes: []align(4) const u8 = std.mem.sliceAsBytes(self.bottom_chunk);

    // Concat to put into one slice
    const b = std.mem.concat(self.allocator, u8, &[_][]const u8{
        data_bytes,
        top_chunk_bytes,
        bottom_chunk_bytes,
    }) catch @panic("OOM");
    defer self.allocator.free(b);

    // Create a reader to use to compress from
    var r = std.io.fixedBufferStream(b);

    // Create a compressor
    var cmp = try std.compress.gzip.compressor(
        writer,
        .{ .level = .default },
    );

    try cmp.compress(r.reader());
    try cmp.finish();
}

test "compress and initFromCompressed" {
    // Set test data
    const b1_block_id: u9 = 9;
    const b2_block_id: u9 = 13;
    const bb1_loc: usize = 301;
    const bb2_loc: usize = 402;
    const bb1: BigBlock.BlockData = BigBlock.BlockData.fromId(b1_block_id);
    const bb2: BigBlock.BlockData = BigBlock.BlockData.fromId(b2_block_id);

    // Create chunk data
    var top_chunk: []u64 = std.testing.allocator.dupe(u64, BigChunk.fully_lit_chunk[0..]) catch @panic("OOM");
    defer std.testing.allocator.free(top_chunk);
    var bottom_chunk: []u64 = std.testing.allocator.dupe(u64, BigChunk.fully_lit_chunk[0..]) catch @panic("OOM");
    defer std.testing.allocator.free(bottom_chunk);

    // Set test data on chunks
    top_chunk[bb1_loc] = bb1.toId();
    bottom_chunk[bb2_loc] = bb2.toId();

    // Set compressor that compresses
    const c1: *Compress = init(std.testing.allocator, top_chunk[0..], bottom_chunk[0..]);
    defer c1.deinit();
    var al = std.ArrayList(u8).init(std.testing.allocator);
    defer al.deinit();
    c1.compress(al.writer());

    // Set compressor that decompresses
    var fbs = std.io.fixedBufferStream(al.items);
    const c2: *Compress = initFromCompressed(std.testing.allocator, fbs.reader());
    defer c2.deinit();

    // Validate the compressed data is what was decompressed
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
