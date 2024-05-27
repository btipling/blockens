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

camera_position: ?@Vector(4, f32) = null,
view: ?zm.Mat = null,
perspective: ?zm.Mat = null,

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
    if (config.use_tracy) {
        const tracy_zone = ztracy.ZoneNC(@src(), "SubChunkSorterBuild", 0x00_ff_ff_f0);
        defer tracy_zone.End();
        self.build();
    } else {
        self.build();
    }
}

fn build(self: *sorter) void {
    if (config.use_tracy) ztracy.Message("sub_chunk_sorter: starting build");
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
    const data_loc: u32 = builder.defineUintAttributeValue(4);
    const attr_trans_loc: u32 = builder.defineFloatAttributeValue(4);
    builder.initBuffer();
    // builder.debug = true;
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
            (cfp[0] * chunk.sub_chunk.sub_chunk_dim) + aloc[0],
            (cfp[1] * chunk.sub_chunk.sub_chunk_dim) + aloc[1],
            (cfp[2] * chunk.sub_chunk.sub_chunk_dim) + aloc[2],
            cfp[3],
        };
        var indices_buf: [chunk.sub_chunk.sub_chunk_size * 36]u32 = undefined;
        var positions_buf: [chunk.sub_chunk.sub_chunk_size * 36][3]u5 = undefined;
        var normals_buf: [chunk.sub_chunk.sub_chunk_size * 36][3]u2 = undefined;
        var block_data_buf: [chunk.sub_chunk.sub_chunk_size * 36]u32 = undefined;
        const res = sc.chunker.getMeshData(
            &indices_buf,
            &positions_buf,
            &normals_buf,
            &block_data_buf,
            full_offset,
        ) catch @panic("no mesh");
        full_offset = res.full_offset;
        if (config.use_tracy) ztracy.Message("sub_chunk_sorter: building vertices");
        for (0..res.positions.len) |ii| {
            const vertex_index: usize = ii + vertex_offset;
            {
                const dp = chunk.sub_chunk.chunker.dataToUint(.{
                    .positions = res.positions[ii],
                    .normals = res.normals[ii],
                });
                const bd: block.BlockData = block.BlockData.fromId(res.block_data[ii]);
                const block_index: u32 = @intCast(game.state.ui.texture_atlas_block_index[@intCast(bd.block_id)]);
                const num_blocks: u32 = @intCast(game.state.ui.texture_atlas_num_blocks);
                const d: [4]u32 = .{ dp, res.block_data[ii], block_index, num_blocks };
                builder.addUintAtLocation(data_loc, &d, vertex_index);
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
    if (config.use_tracy) ztracy.Message("sub_chunk_sorter: done building");
}

fn euclideanDistance(v1: @Vector(4, f32), v2: @Vector(4, f32)) f32 {
    const diff = v1 - v2;
    const diffSquared = diff * diff;
    const sumSquared = zm.dot4(diffSquared, @Vector(4, f32){ 1.0, 1.0, 1.0, 0.0 })[0];
    return std.math.sqrt(sumSquared);
}

pub fn cullFrustum(self: *sorter) void {
    if (self.camera_position == null) return;
    if (self.view == null) return;
    if (self.perspective == null) return;
    if (config.use_tracy) {
        const tracy_zone = ztracy.ZoneNC(@src(), "SubChunkSorterCull", 0x00_ff_ff_f0);
        defer tracy_zone.End();
        self.doCullling(self.camera_position.?, self.view.?, self.perspective.?);
    } else {
        self.doCullling(self.camera_position.?, self.view.?, self.perspective.?);
    }
}

pub fn setCamera(self: *sorter, camera_position: @Vector(4, f32), view: zm.Mat, perspective: zm.Mat) bool {
    if (!self.mutex.tryLock()) return false;
    defer self.mutex.unlock();

    self.camera_position = camera_position;
    self.view = view;
    self.perspective = perspective;
    return true;
}

fn doCullling(self: *sorter, camera_position: @Vector(4, f32), view: zm.Mat, perspective: zm.Mat) void {
    if (config.use_tracy) ztracy.Message("sub_chunk_sorter: start cull");
    var datas: std.ArrayListUnmanaged(*chunk.sub_chunk) = .{};
    {
        self.mutex.lock();
        defer self.mutex.unlock();
        datas = self.all_sub_chunks.clone(self.allocator) catch @panic("OOM");
    }
    defer datas.deinit(self.allocator);

    const count = datas.items.len;
    var sci: usize = 0;
    while (sci < count) : (sci += 1) {
        const sc: *chunk.sub_chunk = datas.items[sci];
        var remove = true;

        const p = sc.wp.vecFromWorldPosition();
        const scp = sc.sub_pos;
        const loc: @Vector(4, f32) = .{
            p[0] * chunk.chunkDim + scp[0] * chunk.sub_chunk.sub_chunk_dim,
            p[1] * chunk.chunkDim + scp[1] * chunk.sub_chunk.sub_chunk_dim,
            p[2] * chunk.chunkDim + scp[2] * chunk.sub_chunk.sub_chunk_dim,
            1,
        };
        const front_bot_l: @Vector(4, f32) = loc;
        const front_bot_r: @Vector(4, f32) = .{
            loc[0] + chunk.sub_chunk.sub_chunk_dim,
            loc[1],
            loc[2],
            loc[3],
        };
        const front_top_l: @Vector(4, f32) = .{
            loc[0],
            loc[1] + chunk.sub_chunk.sub_chunk_dim,
            loc[2],
            loc[3],
        };
        const front_top_r: @Vector(4, f32) = .{
            loc[0] + chunk.sub_chunk.sub_chunk_dim,
            loc[1] + chunk.sub_chunk.sub_chunk_dim,
            loc[2],
            loc[3],
        };
        const back_bot_l: @Vector(4, f32) = .{
            loc[0],
            loc[1],
            loc[2] + chunk.sub_chunk.sub_chunk_dim,
            loc[3],
        };
        const back_bot_r: @Vector(4, f32) = .{
            loc[0] + chunk.sub_chunk.sub_chunk_dim,
            loc[1],
            loc[2] + chunk.sub_chunk.sub_chunk_dim,
            loc[3],
        };
        const back_top_l: @Vector(4, f32) = .{
            loc[0],
            loc[1] + chunk.sub_chunk.sub_chunk_dim,
            loc[2] + chunk.sub_chunk.sub_chunk_dim,
            loc[3],
        };
        const back_top_r: @Vector(4, f32) = .{
            loc[0] + chunk.sub_chunk.sub_chunk_dim,
            loc[1] + chunk.sub_chunk.sub_chunk_dim,
            loc[2] + chunk.sub_chunk.sub_chunk_dim,
            loc[3],
        };
        const to_check: [8]@Vector(4, f32) = .{
            front_bot_l,
            front_bot_r,
            front_top_l,
            front_top_r,
            back_bot_l,
            back_bot_r,
            back_top_l,
            back_top_r,
        };
        for (to_check) |coordinates| {
            const distance_from_camera = euclideanDistance(camera_position, coordinates);
            if (distance_from_camera <= chunk.sub_chunk.sub_chunk_dim) {
                remove = false;
            } else {
                const ca_s: @Vector(4, f32) = zm.mul(coordinates, view);
                const clip_space: @Vector(4, f32) = zm.mul(ca_s, perspective);
                if (-clip_space[3] <= clip_space[0] and clip_space[0] <= clip_space[3] and
                    -clip_space[3] <= clip_space[1] and clip_space[1] <= clip_space[3] and
                    -clip_space[3] <= clip_space[2] and clip_space[2] <= clip_space[3])
                {
                    remove = false;
                }
            }
        }
        datas.items[sci].visible = !remove;
    }

    {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.all_sub_chunks.replaceRange(self.allocator, 0, datas.items.len, datas.items) catch @panic("OOM");
        if (config.use_tracy) ztracy.Message("sub_chunk_sorter: one culling");
        self.doSort(.{ 0, 0, 0, 0 });
    }
}

pub fn sort(self: *sorter, loc: @Vector(4, f32)) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    if (config.use_tracy) {
        const tracy_zone = ztracy.ZoneNC(@src(), "SubChunkSorterSort", 0x00_aa_ff_f0);
        defer tracy_zone.End();
        self.doSort(loc);
    } else {
        self.doSort(loc);
    }
}

fn doSort(self: *sorter, loc: @Vector(4, f32)) void {
    if (config.use_tracy) ztracy.Message("sub_chunk_sorter: starting sort");
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
        if (!sc.visible) {
            index_offset += @intCast(num_indices);
            continue;
        }
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
    if (config.use_tracy) ztracy.Message("sub_chunk_sorter: done sorting");
}

const std = @import("std");
const ztracy = @import("ztracy");
const config = @import("config");
const gfx = @import("../gfx/gfx.zig");
const game = @import("../game.zig");
const zm = @import("zmath");
const block = @import("block.zig");
const chunk = block.chunk;
