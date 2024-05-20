wp: worldPosition,
sub_pos: subPosition,
entity: blecs.ecs.entity_t = 0,
allocator: std.mem.Allocator,

const SubChunk = @This();

pub const subChunkDim = 16;
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
    const sub_pos_x = @divFloor(pos[0], subChunkDim);
    const sub_pos_y = @divFloor(pos[1], subChunkDim);
    const sub_pos_z = @divFloor(pos[2], subChunkDim);

    const sub_index_pos_x: f32 = @mod(pos[0], subChunkDim);
    const sub_index_pos_y: f32 = @mod(pos[1], subChunkDim);
    const sub_index_pos_z: f32 = @mod(pos[2], subChunkDim);

    const sip_x: usize = @intFromFloat(sub_index_pos_x);
    const sip_y: usize = @intFromFloat(sub_index_pos_y);
    const sip_z: usize = @intFromFloat(sub_index_pos_z);

    return .{
        .chunk_pos = pos,
        .chunk_index = chunk.getIndexFromPositionV(pos),
        .sub_pos = .{
            sub_pos_x,
            sub_pos_y,
            sub_pos_z,
            0,
        },
        .sub_index_pos = .{
            sub_index_pos_x,
            sub_index_pos_y,
            sub_index_pos_z,
            0,
        },
        .sub_chunk_index = sip_x + sip_y * subChunkDim + sip_z * subChunkDim * subChunkDim,
    };
}

test subPositionIndex {
    var pos: @Vector(4, f32) = .{ 38, 60, 1, 0 };
    var actual = chunkPosToSubPositionIndex(pos);
    try std.testing.expectEqual(pos, actual.chunk_pos);
    try std.testing.expectEqual(7974, actual.chunk_index);
    try std.testing.expectEqual(.{ 2, 3, 0, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 6, 12, 1, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(454, actual.sub_chunk_index);
    pos = .{ 39, 60, 1, 0 };
    actual = chunkPosToSubPositionIndex(pos);
    try std.testing.expectEqual(7975, actual.chunk_index);
    try std.testing.expectEqual(.{ 2, 3, 0, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 7, 12, 1, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(455, actual.sub_chunk_index);
    pos = .{ 1, 1, 0, 0 };
    actual = chunkPosToSubPositionIndex(pos);
    try std.testing.expectEqual(65, actual.chunk_index);
    try std.testing.expectEqual(.{ 0, 0, 0, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 1, 1, 0, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(17, actual.sub_chunk_index);
    pos = .{ 0, 2, 0, 0 };
    actual = chunkPosToSubPositionIndex(pos);
    try std.testing.expectEqual(128, actual.chunk_index);
    try std.testing.expectEqual(.{ 0, 0, 0, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 0, 2, 0, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(32, actual.sub_chunk_index);
    pos = .{ 1, 2, 0, 0 };
    actual = chunkPosToSubPositionIndex(pos);
    try std.testing.expectEqual(129, actual.chunk_index);
    try std.testing.expectEqual(.{ 0, 0, 0, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 1, 2, 0, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(33, actual.sub_chunk_index);
    pos = .{ 63, 63, 63, 0 };
    actual = chunkPosToSubPositionIndex(pos);
    try std.testing.expectEqual(262_143, actual.chunk_index);
    try std.testing.expectEqual(.{ 3, 3, 3, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 15, 15, 15, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(4_095, actual.sub_chunk_index);
    pos = .{ 63, 0, 0, 0 };
    actual = chunkPosToSubPositionIndex(pos);
    try std.testing.expectEqual(63, actual.chunk_index);
    try std.testing.expectEqual(.{ 3, 0, 0, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 15, 0, 0, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(15, actual.sub_chunk_index);
    pos = .{ 0, 63, 0, 0 };
    actual = chunkPosToSubPositionIndex(pos);
    try std.testing.expectEqual(4_032, actual.chunk_index);
    try std.testing.expectEqual(.{ 0, 3, 0, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 0, 15, 0, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(240, actual.sub_chunk_index);
    pos = .{ 0, 0, 63, 0 };
    actual = chunkPosToSubPositionIndex(pos);
    try std.testing.expectEqual(258_048, actual.chunk_index);
    try std.testing.expectEqual(.{ 0, 0, 3, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 0, 0, 15, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(3_840, actual.sub_chunk_index);
}

const std = @import("std");
const blecs = @import("../blecs/blecs.zig");
const worldPosition = @import("world_position.zig");
const chunk = @import("chunk.zig");
