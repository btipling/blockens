current_format_version: u8 = 0,
data: compressorData = 0,
top_chunk: [chunk.chunkSize]u64 = undefined,
bottom_chunk: [chunk.chunkSize]u64 = undefined,
allocator: std.mem.Allocator,
buffer: ?[]u8 = null, // actually holds the value for above

const Compressor = @This();
const big_chunk_byte_size: usize = chunk.chunkSize * @sizeOf(u64);

const compressorData = packed struct {
    format_version: u8 = 0,
    padding: u56 = 0, // reserved for later and u64 alignment
};

pub fn init(allocator: std.mem.Allocator, top_chunk: []u64, bottom_chunk: []u64) *Compressor {
    const c: *Compressor = allocator.create(Compressor);
    c.* = .{
        .allocator = allocator,
    };
    @memcpy(&c.top_chunk, top_chunk);
    @memcpy(&c.bottom_chunk, bottom_chunk);
    c.toBytes();
    return c;
}

pub fn deinit(self: Compressor) void {
    if (self.buffer) |b| self.allocator.free(b);
    self.allocator.destroy(self);
}

fn toBytes(self: *Compressor) []const u8 {
    const data_bytes: []align(4) const u8 = std.mem.sliceAsBytes(([_]compressorData{self.data})[0..]);
    const top_chunk_bytes: []align(4) const u8 = std.mem.sliceAsBytes(self.top_chunk);
    const bottom_chunk_bytes: []align(4) const u8 = std.mem.sliceAsBytes(self.bottom_chunk);
    if (self.buffer) |b| self.allocator.free(b);
    self.buffer = std.mem.concat(self.allocator, u8, .{
        data_bytes,
        top_chunk_bytes,
        bottom_chunk_bytes,
    }) catch @panic("OOM");
}

fn toData(self: *Compressor, buffer: []const u8) void {
    if (self.buffer) |b| self.allocator.free(b);
    self.buffer = self.allocator.dupe(buffer) catch @panic("OOM");
    var i: usize = @sizeOf(compressorData);
    const data_bytes: []const u8 = buffer[0..i];
    const top_chunk_bytes: []const u8 = buffer[i .. i + big_chunk_byte_size];
    i += big_chunk_byte_size;
    const bottom_chunk_bytes: []const u8 = buffer[i .. i + big_chunk_byte_size];
    self.data = std.mem.bytesToValue(compressorData, data_bytes);
    self.top_chunk = std.mem.bytesToValue([chunk.chunkSize]u64, top_chunk_bytes).*;
    self.top_chunk = std.mem.bytesToValue([chunk.chunkSize]u64, bottom_chunk_bytes).*;
}

const std = @import("std");
const chunk = @import("chunk.zig");
