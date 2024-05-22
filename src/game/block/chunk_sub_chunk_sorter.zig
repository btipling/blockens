index_offset: usize = 0,
allocator: std.mem.Allocator,
all_sub_chunks: std.ArrayListUnmanaged(*chunk.subchunk) = .{},
ebo: u32 = 0,
builder: ?*gfx.buffer_data.AttributeBuilder = null,
num_indices: usize = 0,

opaque_draws: std.ArrayListUnmanaged(c_int) = .{},
opaque_draw_offsets: std.ArrayListUnmanaged(?*const anyopaque) = .{},

const sorter = @This();

pub fn init(allocator: std.mem.Allocator) *sorter {
    const s = allocator.create(sorter) catch @panic("OOM");
    s.* = .{
        .allocator = allocator,
    };
    return s;
}

pub fn addSubChunk(self: *sorter, sc: *chunk.subchunk) void {
    self.all_sub_chunks.append(self.allocator, sc) catch @panic("OOM");
}

pub fn getMeshData(self: *sorter) []u32 {
    const sc: *chunk.subchunk = self.all_sub_chunks.items[0];
    const full_offset: u32 = 0;
    var indices_buf: [chunk.subchunk.subChunkSize * 36]u32 = undefined;
    var vertices_buf: [chunk.subchunk.subChunkSize * 36][3]f32 = undefined;
    const res = sc.chunker.getMeshData(&indices_buf, &vertices_buf, full_offset);
    std.debug.print(
        "idfk bro - \n   indices: {any}\n   vertices: {any}\n   new full offset: {d}\n\n",
        .{
            res.indices,
            res.positions,
            res.full_offset,
        },
    );
    var builder = game.state.allocator.create(
        gfx.buffer_data.AttributeBuilder,
    ) catch @panic("OOM");
    builder.* = gfx.buffer_data.AttributeBuilder.init(
        @intCast(res.positions.len),
        0, // set in gfx_mesh
        0,
    );
    // same order as defined in shader gen, just like gfx_mesh
    const pos_loc: u32 = builder.defineFloatAttributeValue(3);
    builder.initBuffer();

    for (0..res.positions.len) |ii| {
        const vertex_index: usize = ii;
        {
            const p = res.positions[ii];
            builder.addFloatAtLocation(pos_loc, &p, vertex_index);
        }
        builder.nextVertex();
    }
    self.builder = builder;

    const count: usize = res.indices.len;
    var inds = std.ArrayListUnmanaged(u32).initCapacity(
        self.allocator,
        @sizeOf(u32) * count,
    ) catch @panic("OOM");
    errdefer inds.deinit(self.allocator);

    std.debug.print("count: {d}\n", .{count});
    inds.appendSliceAssumeCapacity(res.indices);
    self.num_indices = res.indices.len;
    return inds.toOwnedSlice(self.allocator) catch @panic("OOM");
}

pub fn cullFrustum(self: *sorter, camera_position: @Vector(4, f32), view: zm.Mat, perspective: zm.Mat) void {
    // TODO, culling
    _ = self;
    _ = camera_position;
    _ = view;
    _ = perspective;
}

pub fn sort(self: *sorter, loc: @Vector(4, f32)) void {
    _ = loc; // TODO: sort by loc
    self.opaque_draws.clearRetainingCapacity();
    self.opaque_draw_offsets.clearRetainingCapacity();
    // TODO actually track index per sub chunk.
    // const count = self.all_sub_chunks.items.len;
    // var i: usize = 0;
    // var index_offset: c_uint = 0;
    self.opaque_draws.append(self.allocator, @intCast(self.num_indices)) catch @panic("OOM");
    self.opaque_draw_offsets.append(self.allocator, null) catch @panic("OOM");

    // index_offset += @intCast(self.num_indices);
}

pub fn deinit(self: *sorter) void {
    for (self.all_sub_chunks.items) |sc| {
        sc.deinit();
    }
    self.all_sub_chunks.deinit(self.allocator);
    self.opaque_draws.deinit(self.allocator);
    self.opaque_draw_offsets.deinit(self.allocator);
    self.allocator.destroy(self);
}

const std = @import("std");
const gfx = @import("../gfx/gfx.zig");
const game = @import("../game.zig");
const zm = @import("zmath");
const block = @import("block.zig");
const chunk = block.chunk;
