wp: worldPosition,
entity: blecs.ecs.entity_t = 0,
data: []u32 = undefined,
allocator: std.mem.Allocator,

const Chunk = @This();

pub fn init(
    allocator: std.mem.Allocator,
    wp: worldPosition,
    entity: blecs.ecs.entity_t,
) !*Chunk {
    const c: *Chunk = try allocator.create(Chunk);
    c.* = Chunk{
        .wp = wp,
        .entity = entity,
        .allocator = allocator,
    };
    return c;
}

pub fn deinit(self: *Chunk) void {
    self.allocator.free(self.data);
    self.allocator.destroy(self);
}

const std = @import("std");
const blecs = @import("../blecs/blecs.zig");
const worldPosition = @import("world_position.zig");
