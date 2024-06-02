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
    a.initBoundingBox();
    return a;
}

pub fn deinit(self: *AABB) void {
    var i: usize = 0;
    while (i < self.num_children) : (i += 1) {
        self.children[i].deinit();
    }
    self.allocator.destroy(self);
}

pub fn initBoundingBox(self: *AABB) void {
    const loc = self.slot_position;
    const x_pos_y_neg_z_neg: @Vector(4, f32) = loc;
    const dim: f32 = @floatFromInt(self.dimension);
    const y_dim: f32 = @max(0, @min(chunk.chunkDim, dim));
    const x_pos_y_neg_z_pos: @Vector(4, f32) = .{
        loc[0] + dim,
        loc[1],
        loc[2],
        loc[3],
    };
    const x_pos_y_pos_z_neg: @Vector(4, f32) = .{
        loc[0],
        loc[1] + y_dim,
        loc[2],
        loc[3],
    };
    const x_pos_y_pos_z_pos: @Vector(4, f32) = .{
        loc[0] + dim,
        loc[1] + y_dim,
        loc[2],
        loc[3],
    };
    const x_neg_y_neg_z_neg: @Vector(4, f32) = .{
        loc[0],
        loc[1],
        loc[2] + dim,
        loc[3],
    };
    const x_neg_y_neg_z_pos: @Vector(4, f32) = .{
        loc[0] + dim,
        loc[1],
        loc[2] + dim,
        loc[3],
    };
    const x_neg_y_pos_z_neg: @Vector(4, f32) = .{
        loc[0],
        loc[1] + y_dim,
        loc[2] + dim,
        loc[3],
    };
    const x_neg_y_pos_z_pos: @Vector(4, f32) = .{
        loc[0] + dim,
        loc[1] + y_dim,
        loc[2] + dim,
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

pub fn debugPrintBoundingBox(self: *AABB) void {
    std.debug.print("AABB tree @ ({d}, {d}, {d}, {d}) dimension size: {d} num_children: {d} num_sub_chunks: {d}\n", .{
        self.slot_position[0],
        self.slot_position[1],
        self.slot_position[2],
        self.slot_position[3],
        self.dimension,
        self.num_children,
        self.num_sub_chunks,
    });
    std.debug.print("x_pos_y_neg_z_neg: ({d}, {d}, {d}, {d})\n", .{
        self.bounding_box[0][0],
        self.bounding_box[0][1],
        self.bounding_box[0][2],
        self.bounding_box[0][3],
    });
    std.debug.print("x_pos_y_neg_z_pos: ({d}, {d}, {d}, {d})\n", .{
        self.bounding_box[1][0],
        self.bounding_box[1][1],
        self.bounding_box[1][2],
        self.bounding_box[1][3],
    });
    std.debug.print("x_pos_y_pos_z_neg: ({d}, {d}, {d}, {d})\n", .{
        self.bounding_box[2][0],
        self.bounding_box[2][1],
        self.bounding_box[2][2],
        self.bounding_box[2][3],
    });
    std.debug.print("x_pos_y_pos_z_pos: ({d}, {d}, {d}, {d})\n", .{
        self.bounding_box[3][0],
        self.bounding_box[3][1],
        self.bounding_box[3][2],
        self.bounding_box[3][3],
    });
    std.debug.print("x_neg_y_neg_z_neg: ({d}, {d}, {d}, {d})\n", .{
        self.bounding_box[4][0],
        self.bounding_box[4][1],
        self.bounding_box[4][2],
        self.bounding_box[4][3],
    });
    std.debug.print("x_neg_y_neg_z_pos: ({d}, {d}, {d}, {d})\n", .{
        self.bounding_box[5][0],
        self.bounding_box[5][1],
        self.bounding_box[5][2],
        self.bounding_box[5][3],
    });
    std.debug.print("x_neg_y_pos_z_neg: ({d}, {d}, {d}, {d})\n", .{
        self.bounding_box[6][0],
        self.bounding_box[6][1],
        self.bounding_box[6][2],
        self.bounding_box[6][3],
    });
    std.debug.print("x_neg_y_pos_z_pos: ({d}, {d}, {d}, {d})\n", .{
        self.bounding_box[7][0],
        self.bounding_box[7][1],
        self.bounding_box[7][2],
        self.bounding_box[7][3],
    });
    std.debug.print("\n\n", .{});
}

pub fn addSubChunk(self: *AABB, sc: *const chunk.sub_chunk) void {
    // If smallest possible AABB, just add the sub chunk as a child:
    if (self.dimension == chunk.sub_chunk.sub_chunk_dim * 2) {
        std.debug.assert(self.num_children < 4);
        self.sub_chunks[self.num_children] = sc;
        self.num_sub_chunks += 1;
        return;
    }
    // Want each aabb tree to be aligned to its dimension boundary
    const pos: @Vector(4, f32) = sc.actualWorldSpaceCoordinate();
    const self_dim: f32 = @floatFromInt(self.dimension);
    var self_splatted_dims = @as(@Vector(4, f32), @splat(self_dim / 2));
    self_splatted_dims[1] = @max(0, @min(chunk.chunkDim, self_splatted_dims[0]));
    const bound_offset = @mod(pos, self_splatted_dims);
    const slot_position = pos - bound_offset;
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
    const slot_pos = @Vector(4, f32){ -255, 0, -255, 0 };
    const root: *AABB = init(std.testing.allocator, root_dimension, slot_pos);
    defer root.deinit();

    const wp1: chunk.worldPosition = chunk.worldPosition.getWorldPositionForWorldLocation(.{ 0, 0, 0, 0 });
    const sub_pos1: @Vector(4, f32) = .{ 0, 0, 0, 0 };
    var sc1: chunk.sub_chunk = .{ .wp = wp1, .sub_pos = sub_pos1 };
    sc1.initBoundingBox();
    root.addSubChunk(&sc1);

    try std.testing.expectEqual(1, root.num_children);
    try std.testing.expect(@reduce(.And, root.children[0].slot_position == @Vector(4, f32){ 0, 0, 0, 0 }));
    try std.testing.expect(@reduce(.And, root.children[0]
        .children[0]
        .slot_position == @Vector(4, f32){ 0, 0, 0, 0 }));
    try std.testing.expect(@reduce(.And, root.children[0]
        .children[0]
        .children[0]
        .slot_position == @Vector(4, f32){ 0, 0, 0, 0 }));
    try std.testing.expect(@reduce(.And, root.children[0]
        .children[0]
        .children[0]
        .children[0]
        .slot_position == @Vector(4, f32){ 0, 0, 0, 0 }));
    try std.testing.expect(@reduce(.And, root
        .children[0]
        .children[0]
        .children[0]
        .children[0]
        .sub_chunks[0]
        .sub_pos == sub_pos1));

    const wp2: chunk.worldPosition = chunk.worldPosition.getWorldPositionForWorldLocation(.{ 0, 0, 0, 0 });
    const sub_pos2: @Vector(4, f32) = .{ 1, 1, 0, 0 };
    var sc2: chunk.sub_chunk = .{ .wp = wp2, .sub_pos = sub_pos2 };
    sc2.initBoundingBox();
    root.addSubChunk(&sc2);

    // Should still be 1, as both sub chunks in the same aabb tree at this stage
    try std.testing.expectEqual(1, root.num_children);
    try std.testing.expect(@reduce(.And, root.children[0].slot_position == @Vector(4, f32){ 0, 0, 0, 0 }));
    try std.testing.expect(@reduce(.And, root.children[0]
        .children[0]
        .slot_position == @Vector(4, f32){ 0, 0, 0, 0 }));
    try std.testing.expect(@reduce(.And, root.children[0]
        .children[0]
        .children[0]
        .slot_position == @Vector(4, f32){ 0, 0, 0, 0 }));
    try std.testing.expect(@reduce(.And, root.children[0]
        .children[0]
        .children[0]
        .children[0]
        .slot_position == @Vector(4, f32){ 0, 0, 0, 0 }));
    try std.testing.expectEqual(2, root
        .children[0]
        .children[0]
        .children[0]
        .children[0]
        .num_sub_chunks);

    const wp3: chunk.worldPosition = chunk.worldPosition.getWorldPositionForWorldLocation(.{ -255, 64, -255, 0 });
    const sub_pos3: @Vector(4, f32) = .{ 2, 1, 2, 0 };
    var sc3: chunk.sub_chunk = .{ .wp = wp3, .sub_pos = sub_pos3 };
    sc3.initBoundingBox();
    root.addSubChunk(&sc3);

    // Should be added near the far negative -x -z edge
    try std.testing.expectEqual(2, root.num_children);
    try std.testing.expect(@reduce(.And, root.children[1].slot_position == @Vector(4, f32){ -256, 64, -256, 0 }));
    try std.testing.expect(@reduce(.And, root.children[1]
        .children[0]
        .slot_position == @Vector(4, f32){ -256, 64, -256, 0 }));
    try std.testing.expect(@reduce(.And, root.children[1]
        .children[0]
        .children[0]
        .slot_position == @Vector(4, f32){ -256, 64, -256, 0 }));
    try std.testing.expect(@reduce(.And, root
        .children[1]
        .children[0]
        .children[0]
        .children[0]
        .slot_position == @Vector(4, f32){ -224, 64, -224, 0 }));
    try std.testing.expectEqual(1, root
        .children[1]
        .children[0]
        .children[0]
        .children[0]
        .num_sub_chunks);

    const wp4: chunk.worldPosition = chunk.worldPosition.getWorldPositionForWorldLocation(.{ 192, 0, 192, 0 });
    const sub_pos4: @Vector(4, f32) = .{ 3, 2, 0, 0 };
    var sc4: chunk.sub_chunk = .{ .wp = wp4, .sub_pos = sub_pos4 };
    sc4.initBoundingBox();
    root.addSubChunk(&sc4);

    // Should be added near the far negative -x -z edge
    try std.testing.expectEqual(2, root.num_children);
    try std.testing.expect(@reduce(.And, root.children[1].slot_position == @Vector(4, f32){ -256, 64, -256, 0 }));
    try std.testing.expect(@reduce(.And, root.children[0]
        .children[1]
        .slot_position == @Vector(4, f32){ 128, 0, 128, 0 }));
    try std.testing.expect(@reduce(.And, root.children[0]
        .children[1]
        .children[0]
        .slot_position == @Vector(4, f32){ 192, 0, 192, 0 }));
    try std.testing.expect(@reduce(.And, root
        .children[0]
        .children[1]
        .children[0]
        .children[0]
        .slot_position == @Vector(4, f32){ 224, 32, 192, 0 }));
    try std.testing.expectEqual(1, root
        .children[0]
        .children[1]
        .children[0]
        .children[0]
        .num_sub_chunks);
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
