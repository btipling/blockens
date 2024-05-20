wp: worldPosition,
sub_pos: subPosition,
entity: blecs.ecs.entity_t = 0,
allocator: std.mem.Allocator,

const SubChunk = @This();

pub const subChunkDim = 64;
pub const subChunkSize: comptime_int = subChunkDim * subChunkDim * subChunkDim;

pub const subPosition = @Vector(4, f32);

pub fn init(
    allocator: std.mem.Allocator,
    wp: worldPosition,
    entity: blecs.ecs.entity_t,
    sub_pos: subPosition,
) !*SubChunk {
    const c: *SubChunk = try allocator.create(SubChunk);
    c.* = SubChunk{
        .wp = wp,
        .sub_pos = sub_pos,
        .entity = entity,
        .allocator = allocator,
    };
    return c;
}

pub fn deinit(self: *SubChunk) void {
    self.allocator.free(self.data);
    self.allocator.destroy(self);
}

pub const subPositionIndex = struct {
    // The x, y, z position mapped to an index with in the chunk.chunkSize array
    chunk_pos: @Vector(4, f32) = .{ 0, 0, 0, 0 },
    // A usize index into a chunk.chunkSize array
    chunk_index: usize = 0,
    // The sub chunks offset position within a chunk.chunkSize array, a multiple of subChunkDim
    sub_pos: subPosition = .{ 0, 0, 0, 0 },
    // The x, y, z position mapped to an index within the subChunkSize array
    sub_index_pos: @Vector(4, f32) = .{ 0, 0, 0, 0 },
    // A usize index into a subChunkSize array
    sub_chunk_index: usize = 0,
};

pub fn chunkPosToSubPositionIndex(pos: @Vector(4, f32)) subPositionIndex {
    return .{
        .chunk_pos = pos,
        .chunk_index = chunk.getIndexFromPositionV(pos),
    };
}

test subPositionIndex {
    try std.testing.expect(true);
}

const std = @import("std");
const blecs = @import("../blecs/blecs.zig");
const worldPosition = @import("world_position.zig");
const chunk = @import("chunk.zig");
