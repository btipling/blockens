wp: worldPosition,

entity: blecs.ecs.entity_t = 0,
allocator: std.mem.Allocator,

const SubChunk = @This();

pub fn init(
    allocator: std.mem.Allocator,
    wp: worldPosition,
    entity: blecs.ecs.entity_t,
) !*SubChunk {
    const c: *SubChunk = try allocator.create(SubChunk);
    c.* = SubChunk{
        .wp = wp,
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
