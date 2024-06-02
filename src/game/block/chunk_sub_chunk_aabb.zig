dimension: usize = 0,
slot_position: @Vector(4, f32) = undefined,
bounding_box: [8]@Vector(4, f32) = undefined,
children: [100]*AABB = undefined,
sub_chunks: [4]*const chunk.sub_chunk = undefined,
num_children: usize = 0,
num_sub_chunks: usize = 0,
allocator: std.mem.Allocator,

pub const root_dimension: usize = 512;

const AABB = @This();

pub fn init(allocator: std.mem.Allocator, dimension: usize, slot_position: @Vector(4, f32)) *AABB {
    const a = allocator.create(AABB) catch @panic("OOM");
    errdefer allocator.destroy(a);
    a.* = .{
        .slot_position = slot_position,
        .dimension = dimension,
        .allocator = allocator,
    };
    return a;
}

pub fn deinit(self: *AABB) void {
    self.allocator.destroy(self);
}

pub fn initBoundingBox(self: *AABB) void {
    const loc = self.slot_position;
    const x_pos_y_neg_z_neg: @Vector(4, f32) = loc;
    const x_pos_y_neg_z_pos: @Vector(4, f32) = .{
        loc[0] + self.dimension,
        loc[1],
        loc[2],
        loc[3],
    };
    const x_pos_y_pos_z_neg: @Vector(4, f32) = .{
        loc[0],
        loc[1] + self.dimension,
        loc[2],
        loc[3],
    };
    const x_pos_y_pos_z_pos: @Vector(4, f32) = .{
        loc[0] + self.dimension,
        loc[1] + self.dimension,
        loc[2],
        loc[3],
    };
    const x_neg_y_neg_z_neg: @Vector(4, f32) = .{
        loc[0],
        loc[1],
        loc[2] + self.dimension,
        loc[3],
    };
    const x_neg_y_neg_z_pos: @Vector(4, f32) = .{
        loc[0] + self.dimension,
        loc[1],
        loc[2] + self.dimension,
        loc[3],
    };
    const x_neg_y_pos_z_neg: @Vector(4, f32) = .{
        loc[0],
        loc[1] + self.dimension,
        loc[2] + self.dimension,
        loc[3],
    };
    const x_neg_y_pos_z_pos: @Vector(4, f32) = .{
        loc[0] + self.dimension,
        loc[1] + self.dimension,
        loc[2] + self.dimension,
        loc[3],
    };
    const bounding_box: [8]@Vector(4, f32) = .{
        x_pos_y_neg_z_neg,
        x_pos_y_neg_z_pos,
        x_pos_y_pos_z_neg,
        x_pos_y_pos_z_pos,
        x_neg_y_neg_z_neg,
        x_neg_y_neg_z_pos,
        x_neg_y_pos_z_neg,
        x_neg_y_pos_z_pos,
    };
    self.bounding_box = bounding_box;
}

pub fn addSubChunk(self: *AABB, sc: *const chunk.sub_chunk) void {
    // If smallest possible AABB, just add the sub chunk as a child:
    if (self.dimension == chunk.sub_chunk.sub_chunk_dim * 2) {
        std.debug.assert(self.num_children < 4);
        self.sub_chunks[self.num_children] = sc;
        self.num_children += 1;
    }
    const pos: @Vector(4, f32) = sc.actualWorldSpaceCoordinate();
    // Current bounded world range is -256 -> +256
    const bound_offset = @as(@Vector(4, f32), @splat(256));
    const range_pos = pos + bound_offset;
    const self_dim: f32 = @floatFromInt(self.dimension);
    const offset_slot_pos = range_pos / @as(@Vector(4, f32), @splat(self_dim / 2));
    const slot_position = offset_slot_pos - bound_offset;
    var i: usize = 0;
    while (i < self.num_children) : (i += 1) {
        const child: *AABB = self.children[i];
        if (@reduce(.And, child.slot_position == slot_position)) {
            child.addSubChunk(sc);
            return;
        }
    }
    std.debug.assert(self.num_children < self.children.len - 1);
    var child: *AABB = init(self.allocator, self.dimension / 2, slot_position);
    child.addSubChunk(sc);
    self.children[self.num_children] = child;
    self.num_children += 1;
}

test addSubChunk {
    const slot_pos = @Vector(4, f32){ 0, 0, 0, 0 } - @as(@Vector(4, f32), @splat(256));
    const root: *AABB = init(std.testing.allocator, root_dimension, slot_pos);
    defer root.deinit();

    const wp: chunk.worldPosition = chunk.worldPosition.getWorldPositionForWorldLocation(.{ 0, 0, 0, 0 });
    const sub_pos: @Vector(4, f32) = .{ 0, 0, 0, 0 };

    var sc: chunk.sub_chunk = .{ .wp = wp, .sub_pos = sub_pos };
    sc.initBouningBox();

    root.addSubChunk(&sc);
    try std.testing.expectEqual(1, root.num_children);
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
