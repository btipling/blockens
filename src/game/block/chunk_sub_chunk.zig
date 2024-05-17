wp: worldPosition,
sub_pos: subPosition,
entity: blecs.ecs.entity_t = 0,
allocator: std.mem.Allocator,

const SubChunk = @This();

pub const subPosition = enum {
    pos_x_pos_y,
    pos_x_neg_y,
    neg_x_pos_y,
    neg_x_neg_y,
    pos_z_pos_y,
    pos_z_neg_y,
    neg_z_pos_y,
    neg_z_neg_y,
};

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

const std = @import("std");
const blecs = @import("../blecs/blecs.zig");
const worldPosition = @import("world_position.zig");
const chunk = @import("chunk.zig");
