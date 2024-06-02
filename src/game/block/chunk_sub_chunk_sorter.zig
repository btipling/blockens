index_offset: usize = 0,
allocator: std.mem.Allocator,
all_sub_chunks: [10_000]*chunk.sub_chunk = undefined,
num_sub_chunks: usize = 0,
visible_sub_chunks: [10_000]usize = undefined,
num_visible: usize = 0,
num_indices: usize = 0,

opaque_draw_first: [10_000]c_int = undefined,
opaque_draw_count: [10_000]c_int = undefined,
num_draws: usize = 0,

camera_position: ?@Vector(4, f32) = null,
view: ?zm.Mat = null,
perspective: ?zm.Mat = null,
mesh_buffer_builder: gfx.mesh_buffer_builder,
aabb_tree: *chunk.sub_chunk.aabb_tree,

const sorter = @This();

pub fn init(allocator: std.mem.Allocator, mbb: gfx.mesh_buffer_builder) *sorter {
    const s = allocator.create(sorter) catch @panic("OOM");
    s.* = .{
        .allocator = allocator,
        .mesh_buffer_builder = mbb,
        .aabb_tree = chunk.sub_chunk.aabb_tree.init(
            allocator,
            chunk.sub_chunk.aabb_tree.root_dimension,
            .{ -255, 0, -255, 0 },
        ),
    };
    return s;
}

pub fn deinit(self: *sorter) void {
    var sci: usize = 0;
    while (sci < self.num_sub_chunks) : (sci += 1) {
        self.all_sub_chunks[sci].deinit();
    }
    self.aabb_tree.deinit();
    self.allocator.destroy(self);
}

pub fn clear(self: *sorter) void {
    var sci: usize = 0;
    while (sci < self.num_sub_chunks) : (sci += 1) {
        self.all_sub_chunks[sci].deinit();
    }
    self.mesh_buffer_builder.clear();
    self.num_sub_chunks = 0;
}

pub fn addSubChunk(self: *sorter, sc: *chunk.sub_chunk) void {
    self.all_sub_chunks[self.num_sub_chunks] = sc;
    self.num_sub_chunks += 1;
    if (sc.chunker.total_indices_count == 0) return;
    self.aabb_tree.addSubChunk(sc);
    // self.aabb_tree.debugPrintBoundingBox(true);
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
    var sci: usize = 0;
    self.num_indices = 0;
    while (sci < self.num_sub_chunks) : (sci += 1) {
        const sc: *chunk.sub_chunk = self.all_sub_chunks[sci];
        self.num_indices += sc.chunker.total_indices_count;
    }

    var full_offset: u32 = 0;
    std.debug.print("initing with {d} num indices\n", .{self.num_indices});

    var mesh_data: [chunk.sub_chunk.sub_chunk_size * 36]gfx.gl.mesh_buffer.meshVertexData = undefined;

    var mesh_vertex_data = std.ArrayList(gfx.gl.mesh_buffer.meshVertexData).init(self.allocator);
    defer mesh_vertex_data.deinit();
    var draw_data = std.ArrayList(gfx.gl.draw_buffer.drawData).init(self.allocator);
    defer draw_data.deinit();
    sci = 0;
    while (sci < self.num_sub_chunks) : (sci += 1) {
        const sc: *chunk.sub_chunk = self.all_sub_chunks[sci];
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
        sc.translation = .{
            (cfp[0] * chunk.sub_chunk.sub_chunk_dim) + aloc[0],
            (cfp[1] * chunk.sub_chunk.sub_chunk_dim) + aloc[1],
            (cfp[2] * chunk.sub_chunk.sub_chunk_dim) + aloc[2],
            cfp[3],
        };
        sc.sc_index = sci;
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
            var md: gfx.gl.mesh_buffer.meshVertexData = .{};
            {
                const dp = chunk.sub_chunk.chunker.dataToUint(.{
                    .positions = res.positions[ii],
                    .normals = res.normals[ii],
                });
                const bd: block.BlockData = block.BlockData.fromId(res.block_data[ii]);
                const block_index: u32 = @intCast(game.state.ui.texture_atlas_block_index[@intCast(bd.block_id)]);
                const draw_id: u32 = @intCast(sci);
                md.attr_data = .{ dp, res.block_data[ii], block_index, draw_id };
            }
            mesh_data[ii] = md;
        }
        if (config.use_tracy) ztracy.Message("sub_chunk_sorter: addMeshData");
        mesh_vertex_data.appendSlice(mesh_data[0..res.positions.len]) catch @panic("OOM");
        draw_data.append(.{
            .draw_pointer = [4]u32{ @intCast(sci), 0, 0, 0 },
            .translation = sc.translation,
        }) catch @panic("OOM");
        // sc.buf_index = ad.index;
        // sc.buf_size = ad.size;
        // sc.buf_capacity = ad.capacity;
    }
    self.mesh_buffer_builder.addMeshDataBulk(mesh_vertex_data.items, draw_data.items);
    std.debug.print("total indicies: {d}\n", .{self.num_indices});
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
    self.camera_position = camera_position;
    self.view = view;
    self.perspective = perspective;
    return true;
}

fn doCullling(self: *sorter, camera_position: @Vector(4, f32), view: zm.Mat, perspective: zm.Mat) void {
    if (config.use_tracy) ztracy.Message("sub_chunk_sorter: start cull");

    if (game.state.ui.gfx_use_aabb_chull) {
        self.cullSubChunksWithAABBTree(view);
    } else {
        const count = self.num_sub_chunks;
        var sci: usize = 0;
        while (sci < count) : (sci += 1) {
            if (config.use_tracy) {
                const tracy_zone = ztracy.ZoneNC(@src(), "SubChunkSorterCullSubChunk", 0x00_aa_ff_f0);
                defer tracy_zone.End();
                self.cullSubChunk(camera_position, view, perspective, sci);
            } else {
                self.cullSubChunk(camera_position, view, perspective, sci);
            }
        }
    }

    if (config.use_tracy) ztracy.Message("sub_chunk_sorter: one culling");
    self.doSort(.{ 0, 0, 0, 0 });
}

fn cullSubChunksWithAABBTree(
    self: *sorter,
    view: zm.Mat,
) void {
    self.num_visible = 0;
    var visible_aabb_trees: [10_000]*chunk.sub_chunk.aabb_tree = undefined;
    var num_aabb_trees_left: usize = 0;
    var aabb_tree: *chunk.sub_chunk.aabb_tree = self.aabb_tree;
    std.debug.print("\n\n\ncullSubChunksWithAABBTree begins\n", .{});
    const w: f32 = game.state.ui.screen_size[0];
    const h: f32 = game.state.ui.screen_size[1];
    const s = w / h;
    const f = frustum.init(view, game_config.fov, s, game_config.near, game_config.far);
    while (true) {
        {
            var i: usize = 0;
            while (i < aabb_tree.num_sub_chunks) : (i += 1) {
                std.debug.print("sc visible?, checking. num_visible {d}\n", .{self.num_visible});
                const sc = aabb_tree.sub_chunks[i];
                if (f.axisAlignedBoxVisible(sc.center, sc.effective_radius)) {
                    self.visible_sub_chunks[self.num_visible] = sc.sc_index;
                    std.debug.print("sc visible, adding. num_visible {d}\n", .{self.num_visible});
                    self.num_visible += 1;
                }
            }
        }
        {
            var i: usize = 0;
            while (i < aabb_tree.num_children) : (i += 1) {
                const child = aabb_tree.children[i];
                if (f.axisAlignedBoxVisible(child.center, child.effective_radius)) {
                    visible_aabb_trees[num_aabb_trees_left] = child;
                    num_aabb_trees_left += 1;
                    std.debug.print("visible aabb, adding. left {d}\n", .{num_aabb_trees_left});
                }
            }
        }
        if (num_aabb_trees_left == 0) break;
        aabb_tree = visible_aabb_trees[num_aabb_trees_left - 1];
        num_aabb_trees_left -= 1;
        std.debug.print("checking next aabb, left {d}\n", .{num_aabb_trees_left});
    }
}

fn cullSubChunk(
    self: *sorter,
    camera_position: @Vector(4, f32),
    view: zm.Mat,
    perspective: zm.Mat,
    sci: usize,
) void {
    const sc: *chunk.sub_chunk = self.all_sub_chunks[sci];
    var remove = true;
    for (sc.bounding_box) |coordinates| {
        const distance_from_camera = euclideanDistance(camera_position, coordinates);
        if (distance_from_camera <= chunk.sub_chunk.sub_chunk_dim) {
            remove = false;
        } else if (distance_from_camera > game_config.far) {
            remove = true;
        } else {
            const ca_s: @Vector(4, f32) = zm.mul(coordinates, view);
            const clip_space: @Vector(4, f32) = zm.mul(ca_s, perspective);
            if (!(-clip_space[3] <= clip_space[0])) continue;
            if (!(clip_space[0] <= clip_space[3])) continue;
            if (!(-clip_space[3] <= clip_space[1])) continue;
            if (!(clip_space[1] <= clip_space[3])) continue;
            if (!(-clip_space[3] <= clip_space[2])) continue;
            if (!(clip_space[2] <= clip_space[3])) continue;
            remove = false;
        }
    }
    self.all_sub_chunks[sci].visible = !remove;
}

pub fn sort(self: *sorter, loc: @Vector(4, f32)) void {
    if (config.use_tracy) {
        const tracy_zone = ztracy.ZoneNC(@src(), "SubChunkSorterSort", 0x00_aa_ff_f0);
        defer tracy_zone.End();
        if (game.state.ui.gfx_use_aabb_chull) {
            self.doAABBCulledSort(loc);
            return;
        }
        self.doSort(loc);
    } else {
        if (game.state.ui.gfx_use_aabb_chull) {
            self.doAABBCulledSort(loc);
            return;
        }
        self.doSort(loc);
    }
}

fn doAABBCulledSort(self: *sorter, loc: @Vector(4, f32)) void {
    if (config.use_tracy) ztracy.Message("sub_chunk_sorter: starting aabb sort");
    _ = loc; // TODO: sort by loc
    self.num_draws = 0;
    var index_offset: usize = 0;
    self.mesh_buffer_builder.clearDraws();
    var i: usize = 0;
    while (i < self.num_visible) : (i += 1) {
        const sci = self.visible_sub_chunks[i];
        const sc: *chunk.sub_chunk = self.all_sub_chunks[sci];
        const num_indices = sc.chunker.total_indices_count;
        self.opaque_draw_first[self.num_draws] = @intCast(index_offset);
        self.opaque_draw_count[self.num_draws] = @intCast(num_indices);
        self.num_draws += 1;

        index_offset += @intCast(num_indices);
        i += 1;
    }
    if (config.use_tracy) ztracy.Message("sub_chunk_sorter: done aabb sorting");
}

fn doSort(self: *sorter, loc: @Vector(4, f32)) void {
    if (config.use_tracy) ztracy.Message("sub_chunk_sorter: starting sort");
    _ = loc; // TODO: sort by loc
    self.num_draws = 0;
    // TODO actually track index per sub chunk.
    const count = self.num_sub_chunks;
    var index_offset: usize = 0;
    var sci: usize = 0;
    var i: usize = 0;
    self.mesh_buffer_builder.clearDraws();
    while (sci < count) : (sci += 1) {
        const sc: *chunk.sub_chunk = self.all_sub_chunks[sci];
        const num_indices = sc.chunker.total_indices_count;
        if (num_indices == 0) continue;
        if (!sc.visible) {
            index_offset += @intCast(num_indices);
            continue;
        }
        self.opaque_draw_first[self.num_draws] = @intCast(index_offset);
        self.opaque_draw_count[self.num_draws] = @intCast(num_indices);
        self.num_draws += 1;

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
const game_config = @import("../config.zig");
const zm = @import("zmath");
const frustum = @import("../math/frustum.zig");
const block = @import("block.zig");
const chunk = block.chunk;
