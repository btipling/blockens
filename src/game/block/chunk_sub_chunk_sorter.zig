index_offset: usize = 0,
allocator: std.mem.Allocator,
all_sub_chunks: std.ArrayListUnmanaged(*chunk.sub_chunk) = .{},
ebo: u32 = 0,
builder: ?*gfx.buffer_data.AttributeBuilder = null,
indices: ?[]u32 = null,
num_indices: usize = 0,
mutex: std.Thread.Mutex = .{},

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

pub fn deinit(self: *sorter) void {
    for (self.all_sub_chunks.items) |sc| {
        sc.deinit();
    }
    self.all_sub_chunks.deinit(self.allocator);
    self.opaque_draws.deinit(self.allocator);
    self.opaque_draw_offsets.deinit(self.allocator);
    if (self.builder) |b| b.deinit();
    if (self.indices) |i| self.allocator.free(i);
    self.allocator.destroy(self);
}

pub fn addSubChunk(self: *sorter, sc: *chunk.sub_chunk) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    self.all_sub_chunks.append(self.allocator, sc) catch @panic("OOM");
}

pub fn buildMeshData(self: *sorter) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    var sci: usize = 0;
    self.num_indices = 0;
    while (sci < self.all_sub_chunks.items.len) : (sci += 1) {
        const sc: *chunk.sub_chunk = self.all_sub_chunks.items[sci];
        self.num_indices += sc.chunker.total_indices_count;
    }

    var inds = std.ArrayListUnmanaged(u32).initCapacity(
        self.allocator,
        @sizeOf(u32) * self.num_indices,
    ) catch @panic("OOM");
    errdefer inds.deinit(self.allocator);

    var full_offset: u32 = 0;
    var builder = game.state.allocator.create(
        gfx.buffer_data.AttributeBuilder,
    ) catch @panic("OOM");
    std.debug.print("initing with {d} num indices\n", .{self.num_indices});

    builder.* = gfx.buffer_data.AttributeBuilder.init(
        @intCast(self.num_indices),
        0, // set in gfx_mesh
        0,
    );
    // same order as defined in shader gen, just like gfx_mesh
    const pos_loc: u32 = builder.defineFloatAttributeValue(3);
    const nor_loc: u32 = builder.defineFloatAttributeValue(3);
    const block_data_loc: u32 = builder.defineFloatAttributeValue(4);
    const attr_trans_loc: u32 = builder.defineFloatAttributeValue(4);
    builder.initBuffer();
    sci = 0;
    var vertex_offset: usize = 0;
    while (sci < self.all_sub_chunks.items.len) : (sci += 1) {
        const sc: *chunk.sub_chunk = self.all_sub_chunks.items[sci];
        if (sc.chunker.total_indices_count == 0) continue;
        const cp = sc.wp.getWorldLocation();
        var loc: @Vector(4, f32) = undefined;
        loc = .{
            cp[0],
            cp[1],
            cp[2],
            0,
        };
        const aloc: @Vector(4, f32) = loc - @as(@Vector(4, f32), @splat(0.5));

        const cfp: @Vector(4, f32) = sc.sub_pos;
        const translation: @Vector(4, f32) = .{
            (cfp[0] * chunk.sub_chunk.subChunkDim) + aloc[0],
            (cfp[1] * chunk.sub_chunk.subChunkDim) + aloc[1],
            (cfp[2] * chunk.sub_chunk.subChunkDim) + aloc[2],
            cfp[3],
        };
        var indices_buf: [chunk.sub_chunk.subChunkSize * 36]u32 = undefined;
        var vertices_buf: [chunk.sub_chunk.subChunkSize * 36][3]f32 = undefined;
        var normals_buf: [chunk.sub_chunk.subChunkSize * 36][3]f32 = undefined;
        var block_data_buf: [chunk.sub_chunk.subChunkSize * 36]u32 = undefined;
        const res = sc.chunker.getMeshData(
            &indices_buf,
            &vertices_buf,
            &normals_buf,
            &block_data_buf,
            full_offset,
        ) catch @panic("no mesh");
        full_offset = res.full_offset;
        for (0..res.positions.len) |ii| {
            const vertex_index: usize = ii + vertex_offset;
            {
                const p = res.positions[ii];
                builder.addFloatAtLocation(pos_loc, &p, vertex_index);
            }
            {
                const n = res.normals[ii];
                builder.addFloatAtLocation(nor_loc, &n, vertex_index);
            }
            {
                const bd: block.BlockData = block.BlockData.fromId(res.block_data[ii]);
                const ambient: f32 = @bitCast(@as(u32, @intCast(bd.ambient)));
                const lighting: f32 = @bitCast(@as(u32, @intCast(bd.lighting)));
                const block_index: f32 = @floatFromInt(game.state.ui.texture_atlas_block_index[@intCast(bd.block_id)]);
                const num_blocks: f32 = @floatFromInt(game.state.ui.texture_atlas_num_blocks);
                const _bd: [4]f32 = [_]f32{ block_index, num_blocks, ambient, lighting };
                builder.addFloatAtLocation(block_data_loc, &_bd, vertex_index);
            }
            {
                const atr_data: [4]f32 = translation;
                builder.addFloatAtLocation(attr_trans_loc, &atr_data, vertex_index);
            }
            builder.nextVertex();
        }

        inds.appendSliceAssumeCapacity(res.indices);
        vertex_offset += sc.chunker.total_indices_count;
    }
    self.builder = builder;
    std.debug.print("total indicies: {d}\n", .{self.num_indices});
    self.indices = inds.toOwnedSlice(self.allocator) catch @panic("OOM");
}

pub fn cullFrustum(self: *sorter, camera_position: @Vector(4, f32), view: zm.Mat, perspective: zm.Mat) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    // TODO, culling
    _ = camera_position;
    _ = view;
    _ = perspective;
}

pub fn sort(self: *sorter, loc: @Vector(4, f32)) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    _ = loc; // TODO: sort by loc
    self.opaque_draws.clearRetainingCapacity();
    self.opaque_draw_offsets.clearRetainingCapacity();
    // TODO actually track index per sub chunk.
    const count = self.all_sub_chunks.items.len;
    var index_offset: usize = 0;
    var sci: usize = 0;
    var i: usize = 0;
    while (sci < count) : (sci += 1) {
        const sc: *chunk.sub_chunk = self.all_sub_chunks.items[sci];
        const num_indices = sc.chunker.total_indices_count;
        if (num_indices == 0) continue;
        self.opaque_draws.append(self.allocator, @intCast(num_indices)) catch @panic("OOM");
        if (i == 0) {
            self.opaque_draw_offsets.append(self.allocator, null) catch @panic("OOM");
        } else {
            const offset: usize = (@sizeOf(c_uint) * index_offset);
            self.opaque_draw_offsets.append(
                self.allocator,
                @as(*anyopaque, @ptrFromInt(offset)),
            ) catch @panic("OOM");
        }
        index_offset += @intCast(num_indices);
        i += 1;
    }
}

const std = @import("std");
const gfx = @import("../gfx/gfx.zig");
const game = @import("../game.zig");
const zm = @import("zmath");
const block = @import("block.zig");
const chunk = block.chunk;
