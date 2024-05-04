// chunk_traverse exists to stop with bad inline chunk traverser code that's hard to understand
// bug prone, and a source of frustration. This is a building block to make things
// that need to occur accros chunks easier with this specialized one purpose tool
// to do a thing that inside other code just makes everything too complicated.
// As a stand alone tool it should be easy to understand.
fetcher: data_fetcher,
current_wp: worldPosition,
// position is just the original position updated beyond chunk ranges to make math easy
position: @Vector(4, f32),
// chunk_position is the current position inside an actual chunk
chunk_position: @Vector(4, f32),
// world_location is the current position in world space.
world_location: @Vector(4, f32),
current_data: []u32 = undefined,
current_ci: usize,
current_bd: block.BlockData = undefined,
// original data to reset to:
og_wp: worldPosition,
og_position: @Vector(4, f32),
og_ci: usize,
og_world_location: @Vector(4, f32),
og_data: []u32 = undefined,
og_bd: block.BlockData = undefined,
// fetched datas state
datas: [8]datas = undefined,
num_extra_datas: u8 = 0,
allocator: std.mem.Allocator,
num_traversals: u64 = 0,
lowest_y: f32 = 1000,
highest_y: f32 = -1000,

const traverser = @This();

// Writing to a fake fully lit chunk is not recommended. It won't be saved, it doesn't
// really exist and will probably break since it's the same data for all fake chunks.
// Exists for lighting. It should never be dark since there are no blocks to
// block ambient light. It may be momentarily dark while block editing is processing
// lighting.
const fl_chunk_dim: f32 = @as(f32, @floatFromInt(chunk.chunkDim));

pub const datas = struct {
    wp: chunk.worldPosition,
    data: ?[]u32 = null,
    fetchable: bool = true,
};

// pos in this parameter is a chunk position, indicies bound by chunkDim, not a location in world
pub fn init(allocator: std.mem.Allocator, fetcher: data_fetcher, wp: worldPosition, ci: usize, initial_datas: datas) traverser {
    const pos = chunk.getPositionAtIndexV(ci);
    const world_location = wp.getWorldLocationForPosition(pos);
    var rv: traverser = .{
        .fetcher = fetcher,
        .current_wp = wp,
        .og_wp = wp,
        .position = pos,
        .chunk_position = pos,
        .og_position = pos,
        .world_location = world_location,
        .og_world_location = world_location,
        .current_ci = ci,
        .og_ci = ci,
        .allocator = allocator,
    };
    rv.datas[0] = initial_datas;
    rv.current_data = traverser.get_datas(&rv, wp) orelse std.debug.panic(
        "initialized traverser with an empty chunk",
        .{},
    );
    rv.og_data = rv.current_data;
    rv.current_bd = block.BlockData.fromId(rv.current_data[rv.current_ci]);
    rv.og_bd = rv.current_bd;
    return rv;
}

pub fn deinit(self: traverser) void {
    var i: usize = 1;
    while (i < self.num_extra_datas + 1) : (i += 1) {
        const d = self.datas[i];
        if (!d.fetchable) continue;
        if (d.data) |cd| self.allocator.free(cd);
    }
}

pub fn reset(self: *traverser) void {
    self.current_wp = self.og_wp;
    self.position = self.og_position;
    self.chunk_position = self.og_position;
    self.current_ci = self.og_ci;
    self.current_data = self.og_data;
    self.current_bd = self.og_bd;
}

pub fn xPos(self: *traverser) void {
    self.num_traversals += 1;
    self.position[0] += 1;
    self.world_location[0] += 1;
    self.chunk_position[0] += 1;
    if (self.chunk_position[0] >= fl_chunk_dim) {
        self.chunk_position[0] = self.chunk_position[0] - fl_chunk_dim;
        self.current_wp = self.current_wp.getXPosWP();
        self.current_data = self.get_datas(self.current_wp) orelse fully_lit_chunk[0..];
    }
    self.current_ci = chunk.getIndexFromPositionV(self.chunk_position);
    self.current_bd = block.BlockData.fromId(self.current_data[self.current_ci]);
}

pub fn xNeg(self: *traverser) void {
    self.num_traversals += 1;
    self.position[0] -= 1;
    self.world_location[0] -= 1;
    self.chunk_position[0] -= 1;
    if (self.chunk_position[0] < 0) {
        self.chunk_position[0] = fl_chunk_dim + self.chunk_position[0];
        self.current_wp = self.current_wp.getXNegWP();
        self.current_data = self.get_datas(self.current_wp) orelse fully_lit_chunk[0..];
    }
    self.current_ci = chunk.getIndexFromPositionV(self.chunk_position);
    self.current_bd = block.BlockData.fromId(self.current_data[self.current_ci]);
}

// xMoveTo - go to x in self.position, disregarding chunkDim boundaries
pub fn xMoveTo(self: *traverser, x: f32) void {
    if (self.position[0] == x) return;
    if (self.position[0] < x) {
        while (self.position[0] != x) {
            self.xPos();
        }
        return;
    }
    while (self.position[0] != x) {
        self.xNeg();
    }
}

pub fn yPos(self: *traverser) void {
    self.num_traversals += 1;
    self.position[1] += 1;
    self.world_location[1] += 1;
    self.chunk_position[1] += 1;
    if (self.chunk_position[1] >= fl_chunk_dim) {
        self.chunk_position[1] = self.chunk_position[1] - fl_chunk_dim;
        self.current_wp = self.current_wp.getYPosWP();
        self.current_data = self.get_datas(self.current_wp) orelse fully_lit_chunk[0..];
    }
    self.current_ci = chunk.getIndexFromPositionV(self.chunk_position);
    self.current_bd = block.BlockData.fromId(self.current_data[self.current_ci]);
    if (self.position[1] > self.highest_y) self.highest_y = self.position[1];
}

pub fn yNeg(self: *traverser) void {
    self.num_traversals += 1;
    self.position[1] -= 1;
    self.world_location[1] -= 1;
    self.chunk_position[1] -= 1;
    if (self.chunk_position[1] < 0) {
        self.chunk_position[1] = fl_chunk_dim + self.chunk_position[1];
        self.current_wp = self.current_wp.getYNegWP();
        self.current_data = self.get_datas(self.current_wp) orelse fully_lit_chunk[0..];
    }
    self.current_ci = chunk.getIndexFromPositionV(self.chunk_position);
    self.current_bd = block.BlockData.fromId(self.current_data[self.current_ci]);
    if (self.position[1] < self.lowest_y) self.lowest_y = self.position[1];
}

// yMoveTo - go to y in self.position, disregarding chunkDim boundaries
pub fn yMoveTo(self: *traverser, y: f32) void {
    if (self.position[1] == y) return;
    if (self.position[1] < y) {
        while (self.position[1] != y) {
            self.yPos();
        }
        return;
    }
    while (self.position[1] != y) {
        self.yNeg();
    }
}

pub fn zPos(self: *traverser) void {
    self.num_traversals += 1;
    self.position[2] += 1;
    self.world_location[2] += 1;
    self.chunk_position[2] += 1;
    if (self.chunk_position[2] >= fl_chunk_dim) {
        self.chunk_position[2] = self.chunk_position[2] - fl_chunk_dim;
        self.current_wp = self.current_wp.getZPosWP();
        self.current_data = self.get_datas(self.current_wp) orelse fully_lit_chunk[0..];
    }
    self.current_ci = chunk.getIndexFromPositionV(self.chunk_position);
    self.current_bd = block.BlockData.fromId(self.current_data[self.current_ci]);
}

pub fn zNeg(self: *traverser) void {
    self.num_traversals += 1;
    self.position[2] -= 1;
    self.world_location[2] -= 1;
    self.chunk_position[2] -= 1;
    if (self.chunk_position[2] < 0) {
        self.chunk_position[2] = fl_chunk_dim + self.chunk_position[2];
        self.current_wp = self.current_wp.getZNegWP();
        self.current_data = self.get_datas(self.current_wp) orelse fully_lit_chunk[0..];
    }
    self.current_ci = chunk.getIndexFromPositionV(self.chunk_position);
    self.current_bd = block.BlockData.fromId(self.current_data[self.current_ci]);
}

// zMoveTo - go to z in self.position, disregarding chunkDim boundaries
pub fn zMoveTo(self: *traverser, z: f32) void {
    if (self.position[2] == z) return;
    if (self.position[2] < z) {
        while (self.position[2] != z) {
            self.zPos();
        }
        return;
    }
    while (self.position[2] != z) {
        self.zNeg();
    }
}

pub fn saveBD(self: *traverser) void {
    self.current_data[self.current_ci] = self.current_bd.toId();
}

pub fn get_datas(self: *traverser, wp: chunk.worldPosition) ?[]u32 {
    var i: usize = 0;
    while (i < self.num_extra_datas + 1) : (i += 1) {
        const d = self.datas[i];
        if (d.wp.equal(wp)) {
            if (d.fetchable) {
                return d.data;
            }
            return null;
        }
    }
    if (self.num_extra_datas + 1 == self.datas.len) @panic("too many datas fetched >:|");

    const d = self.fetcher.fetch(wp) orelse {
        const ed: datas = .{
            .wp = wp,
            .fetchable = false,
        };
        self.datas[self.num_extra_datas + 1] = ed;
        self.num_extra_datas += 1;
        return null;
    };

    self.datas[self.num_extra_datas + 1] = d;
    self.num_extra_datas += 1;
    return d.data;
}

pub fn debugPrint(self: traverser) void {
    std.debug.print("\n\n::chunk_traverser:: \n", .{});
    std.debug.print("\t - og position: ({d}, {d}, {d})\n", .{ self.og_position[0], self.og_position[1], self.og_position[2] });
    std.debug.print("\t - position: ({d}, {d}, {d})\n", .{ self.position[0], self.position[1], self.position[2] });
    std.debug.print("\t - chunk_position: ({d}, {d}, {d})\n", .{ self.chunk_position[0], self.chunk_position[1], self.chunk_position[2] });
    std.debug.print("\t - world_location: ({d}, {d}, {d})\n", .{ self.world_location[0], self.world_location[1], self.world_location[2] });
    std.debug.print("\t - chunk_index: ({d})\n", .{self.current_ci});
    std.debug.print("\t - og_ci: ({d})\n", .{self.og_ci});
    std.debug.print("\t - bd.block_id: {d}\n", .{self.current_bd.block_id});
    std.debug.print("\t - og.block_id: {d}\n", .{self.og_bd.block_id});
    std.debug.print("\t - bd.ambient: {d}\n", .{self.current_bd.ambient});
    std.debug.print("\t - bd.lighting: {d}\n", .{self.current_bd.lighting});
    std.debug.print("\t - num_traversals: {d}\n", .{self.num_traversals});
    std.debug.print("\t - num_extra_datas: {d}\n", .{self.num_extra_datas});
    std.debug.print("\t - lowest_y: {d}\n", .{self.lowest_y});
    std.debug.print("\t - highest_y: {d}\n", .{self.highest_y});

    std.debug.print("\n\n", .{});
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
const worldPosition = chunk.worldPosition;
var fully_lit_chunk: [chunk.chunkSize]u32 = chunk.fully_lit_chunk;
const data_fetcher = if (@import("builtin").is_test)
    (@import("test_data_fetcher.zig"))
else
    @import("data_fetcher.zig");
