wp: worldPosition,
sub_pos: subPosition,
chunker: chunker,
visible: bool = true,

buf_index: usize = 0,
buf_size: usize = 0,
buf_capacity: usize = 0,

allocator: std.mem.Allocator,

const SubChunk = @This();

pub const sub_chunk_dim = 16;
pub const sub_chunk_size: comptime_int = sub_chunk_dim * sub_chunk_dim * sub_chunk_dim;

pub const subPosition = @Vector(4, f32);

pub fn init(
    allocator: std.mem.Allocator,
    wp: worldPosition,
    sub_pos: subPosition,
    csc: chunker,
) !*SubChunk {
    const c: *SubChunk = try allocator.create(SubChunk);
    c.* = SubChunk{
        .wp = wp,
        .sub_pos = sub_pos,
        .chunker = csc,
        .allocator = allocator,
    };
    return c;
}

pub fn deinit(self: *SubChunk) void {
    self.allocator.destroy(self);
}

pub const subPositionIndex = struct {
    // The x, y, z position mapped to an index with in the chunk.chunkSize array
    chunk_pos: @Vector(4, f32) = .{ 0, 0, 0, 0 },
    // A usize index into a chunk.chunkSize array
    chunk_index: usize = 0,
    // The sub chunks offset position within a chunk.chunkSize array, a multiple of sub_chunk_dim
    sub_pos: subPosition = .{ 0, 0, 0, 0 },
    // The x, y, z position mapped to an index within the sub_chunk_size array
    sub_index_pos: @Vector(4, u4) = .{ 0, 0, 0, 0 },
    // A usize index into a sub_chunk_size array
    sub_chunk_index: usize = 0,
};

pub fn subChunkPosToSubPositionData(pos: @Vector(4, u4)) usize {
    const sip_x: usize = @intCast(pos[0]);
    const sip_y: usize = @intCast(pos[1]);
    const sip_z: usize = @intCast(pos[2]);
    return sip_x + sip_y * sub_chunk_dim + sip_z * sub_chunk_dim * sub_chunk_dim;
}

pub fn chunkPosToSubPositionData(pos: @Vector(4, f32)) subPositionIndex {
    const sub_pos_x = @divFloor(pos[0], sub_chunk_dim);
    const sub_pos_y = @divFloor(pos[1], sub_chunk_dim);
    const sub_pos_z = @divFloor(pos[2], sub_chunk_dim);

    const sub_index_pos_x: u4 = @intCast(@mod(@as(usize, @intFromFloat(pos[0])), sub_chunk_dim));
    const sub_index_pos_y: u4 = @intCast(@mod(@as(usize, @intFromFloat(pos[1])), sub_chunk_dim));
    const sub_index_pos_z: u4 = @intCast(@mod(@as(usize, @intFromFloat(pos[2])), sub_chunk_dim));

    const sc_pos: @Vector(4, u4) = .{
        sub_index_pos_x,
        sub_index_pos_y,
        sub_index_pos_z,
        0,
    };
    return .{
        .chunk_pos = pos,
        .chunk_index = chunk.getIndexFromPositionV(pos),
        .sub_pos = .{
            sub_pos_x,
            sub_pos_y,
            sub_pos_z,
            0,
        },
        .sub_index_pos = sc_pos,
        .sub_chunk_index = subChunkPosToSubPositionData(sc_pos),
    };
}

test subPositionIndex {
    var pos: @Vector(4, f32) = .{ 38, 60, 1, 0 };
    var actual = chunkPosToSubPositionData(pos);
    try std.testing.expectEqual(pos, actual.chunk_pos);
    try std.testing.expectEqual(7974, actual.chunk_index);
    try std.testing.expectEqual(.{ 2, 3, 0, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 6, 12, 1, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(454, actual.sub_chunk_index);
    pos = .{ 39, 60, 1, 0 };
    actual = chunkPosToSubPositionData(pos);
    try std.testing.expectEqual(7975, actual.chunk_index);
    try std.testing.expectEqual(.{ 2, 3, 0, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 7, 12, 1, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(455, actual.sub_chunk_index);
    pos = .{ 1, 1, 0, 0 };
    actual = chunkPosToSubPositionData(pos);
    try std.testing.expectEqual(65, actual.chunk_index);
    try std.testing.expectEqual(.{ 0, 0, 0, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 1, 1, 0, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(17, actual.sub_chunk_index);
    pos = .{ 0, 2, 0, 0 };
    actual = chunkPosToSubPositionData(pos);
    try std.testing.expectEqual(128, actual.chunk_index);
    try std.testing.expectEqual(.{ 0, 0, 0, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 0, 2, 0, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(32, actual.sub_chunk_index);
    pos = .{ 1, 2, 0, 0 };
    actual = chunkPosToSubPositionData(pos);
    try std.testing.expectEqual(129, actual.chunk_index);
    try std.testing.expectEqual(.{ 0, 0, 0, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 1, 2, 0, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(33, actual.sub_chunk_index);
    pos = .{ 63, 63, 63, 0 };
    actual = chunkPosToSubPositionData(pos);
    try std.testing.expectEqual(262_143, actual.chunk_index);
    try std.testing.expectEqual(.{ 3, 3, 3, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 15, 15, 15, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(4_095, actual.sub_chunk_index);
    pos = .{ 63, 0, 0, 0 };
    actual = chunkPosToSubPositionData(pos);
    try std.testing.expectEqual(63, actual.chunk_index);
    try std.testing.expectEqual(.{ 3, 0, 0, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 15, 0, 0, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(15, actual.sub_chunk_index);
    pos = .{ 0, 63, 0, 0 };
    actual = chunkPosToSubPositionData(pos);
    try std.testing.expectEqual(4_032, actual.chunk_index);
    try std.testing.expectEqual(.{ 0, 3, 0, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 0, 15, 0, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(240, actual.sub_chunk_index);
    pos = .{ 0, 0, 63, 0 };
    actual = chunkPosToSubPositionData(pos);
    try std.testing.expectEqual(258_048, actual.chunk_index);
    try std.testing.expectEqual(.{ 0, 0, 3, 0 }, actual.sub_pos);
    try std.testing.expectEqual(.{ 0, 0, 15, 0 }, actual.sub_index_pos);
    try std.testing.expectEqual(3_840, actual.sub_chunk_index);
}

const std = @import("std");
const blecs = @import("../blecs/blecs.zig");
const worldPosition = @import("world_position.zig");
const chunk = @import("chunk.zig");

pub const sorter = @import("chunk_sub_chunk_sorter.zig");
pub const chunker = @import("chunk_sub_chunker.zig");
