pub const chunkDim = 64;
pub const chunkSize: comptime_int = chunkDim * chunkDim * chunkDim;
const drawSize = chunkDim * chunkDim;

const air: u8 = 0;

pub fn getBlockId(pos: @Vector(4, f32)) dataAtRes {
    const wp = worldPosition.getWorldPositionForWorldLocation(pos);
    const c = game.state.blocks.game_chunks.get(wp) orelse return .{ .read = true, .data = 0 };
    const chunk_local_pos = chunkBlockPosFromWorldLocation(pos);
    const chunk_index = getIndexFromPositionV(chunk_local_pos);
    return c.dataAt(chunk_index);
}

pub fn createEditedChunk(wp: worldPosition, pos: @Vector(4, f32), block_id: u8) void {
    const chunk_local_pos = chunkBlockPosFromWorldLocation(pos);
    const chunk_index = getIndexFromPositionV(chunk_local_pos);
    if (game.state.ui.data.world_chunk_table_data.get(wp) != null) {
        // Chunk not previously generated, but maybe we already updated it before generating.
        // Ignore edits untl that's done. Don't want two code paths to deal with updated but not yet generated nonsense.
        return;
    }
    const cd: []u32 = game.state.allocator.alloc(u32, fully_lit_chunk.len) catch @panic("OOM");
    @memcpy(cd, fully_lit_chunk[0..]);
    cd[chunk_index] = block_id;
    const new_ch_cfg: game_state.chunkConfig = .{
        .id = 0,
        .scriptId = 0,
        .chunkData = cd,
    };
    game.state.ui.data.world_chunk_table_data.put(wp, new_ch_cfg) catch @panic("OOM");
    _ = game.state.jobs.copyChunk(
        wp,
        blecs.ecs.new_id(game.state.world),
        false,
        true,
    );
    return;
}

pub fn setBlockId(pos: @Vector(4, f32), block_id: u8) ?worldPosition {
    const wp = worldPosition.getWorldPositionForWorldLocation(pos);
    const chunk_local_pos = chunkBlockPosFromWorldLocation(pos);
    const chunk_index = getIndexFromPositionV(chunk_local_pos);
    // Get chunk from chunk state map:
    var bd: block.BlockData = undefined;
    var c = game.state.blocks.game_chunks.get(wp) orelse return null;
    const c_data = game.state.allocator.alloc(u32, chunkSize) catch @panic("OOM");
    defer game.state.allocator.free(c_data);
    {
        c.mutex.lock();
        defer c.mutex.unlock();
        @memcpy(c_data, c.data);
    }

    bd = block.BlockData.fromId(c_data[chunk_index]);
    bd.block_id = block_id;
    c_data[chunk_index] = bd.toId();
    var traverser = chunk_traverser.init(game.state.allocator, .{}, c.wp, chunk_index, .{
        .wp = c.wp,
        .data = c_data,
    });
    defer traverser.deinit();

    var l = lighting{
        .traverser = &traverser,
    };

    if (config.use_tracy) {
        const tracy_zone = ztracy.ZoneNC(@src(), "LightAmbientEdit", 0xF0_00_f0_f0);
        std.debug.print("in zone\n", .{});
        defer tracy_zone.End();
        if (block_id == air) {
            l.set_removed_block_lighting();
        } else {
            l.set_added_block_lighting();
        }
    } else {
        if (block_id == air) {
            l.set_removed_block_lighting();
        } else {
            l.set_added_block_lighting();
        }
    }
    {
        c.mutex.lock();
        defer c.mutex.unlock();
        @memcpy(c.data, c_data);
        c.updated = true;
    }
    var i: usize = 1;
    while (i < traverser.num_extra_datas + 1) : (i += 1) {
        const d = traverser.datas[i];
        if (!d.fetchable) continue;
        const c_c_data = d.data orelse continue;
        const c_wp = d.wp;
        var c_c: *Chunk = game.state.blocks.game_chunks.get(c_wp) orelse continue;
        {
            c_c.mutex.lock();
            defer c_c.mutex.unlock();
            @memcpy(c_c.data, c_c_data);
            c_c.updated = true;
        }
        c_c.refreshRender(game.state.world);
    }
    return wp;
}

pub fn chunkBlockPosFromWorldLocation(loc: @Vector(4, f32)) @Vector(4, f32) {
    const cd: f32 = @floatFromInt(chunkDim);
    const changer: @Vector(4, f32) = @splat(cd);
    const p = @mod(loc, changer);
    return @floor(p);
}

pub fn getPositionAtIndexV(i: usize) @Vector(4, f32) {
    const x = @as(f32, @floatFromInt(@mod(i, chunkDim)));
    const y = @as(f32, @floatFromInt(@mod(i / chunkDim, chunkDim)));
    const z = @as(f32, @floatFromInt(i / (chunkDim * chunkDim)));
    return @Vector(4, f32){ x, y, z, 0 };
}

pub fn getIndexFromPositionV(p: @Vector(4, f32)) usize {
    const x = @as(u32, @intFromFloat(p[0]));
    const y = @as(u32, @intFromFloat(p[1]));
    const z = @as(u32, @intFromFloat(p[2]));
    return @as(
        usize,
        @intCast(@mod(x, chunkDim) + @mod(y, chunkDim) * chunkDim + @mod(z, chunkDim) * chunkDim * chunkDim),
    );
}

pub const dataAtRes = struct {
    read: bool = false,
    data: u32 = 0,
};

pub const Chunk = struct {
    wp: worldPosition,
    entity: blecs.ecs.entity_t = 0,
    data: []u32 = undefined,
    allocator: std.mem.Allocator,
    attr_builder: ?*gfx.buffer_data.AttributeBuilder = null,
    indices: ?[]u32 = null,
    draws: ?[]c_int = null,
    draw_offsets: ?[]c_int = null, // this only exists to hold the values that draw_offsets_gl points to...
    draw_offsets_gl: ?[]?*const anyopaque = null,
    prev_draw_offsets_gl: ?[]?*const anyopaque = null,
    prev_draws: ?[]c_int = null,
    is_settings: bool = false,
    updated: bool = false,
    vbo: u32 = 0,
    mutex: std.Thread.Mutex = .{},
    // Lock mesh jobs from spawning while one is on going.
    mesh_mutex: std.Thread.Mutex = .{},
    pub fn init(
        allocator: std.mem.Allocator,
        wp: worldPosition,
        entity: blecs.ecs.entity_t,
        is_settings: bool,
    ) !*Chunk {
        const c: *Chunk = try allocator.create(Chunk);
        c.* = Chunk{
            .wp = wp,
            .entity = entity,
            .allocator = allocator,
            .is_settings = is_settings,
        };
        return c;
    }

    pub fn dataAt(self: *Chunk, i: usize) dataAtRes {
        if (!self.mutex.tryLock()) {
            return .{ .read = false, .data = 0 };
        }
        defer self.mutex.unlock();
        return .{ .read = true, .data = self.data[i] };
    }

    pub fn refreshRender(self: *Chunk, world: *blecs.ecs.world_t) void {
        const render_entity = blecs.ecs.get_target(
            world,
            self.entity,
            blecs.entities.block.HasChunkRenderer,
            0,
        );
        _ = game.state.jobs.meshChunk(world, render_entity, self);
    }

    pub fn deinit(self: *Chunk) void {
        self.deinitRenderData();
        self.deinitRenderPreviousData();
        self.allocator.free(self.data);
        if (self.attr_builder) |b| b.deinit();
        if (self.indices) |i| self.allocator.free(i);
    }

    pub fn backupDrawsData(self: *Chunk) void {
        self.deinitRenderPreviousData();
        self.prev_draws = self.draws;
        self.prev_draw_offsets_gl = self.draw_offsets_gl;
    }

    pub fn deinitRenderData(self: *Chunk) void {
        self.backupDrawsData();
        if (self.draw_offsets) |d| self.allocator.free(d);
        self.draw_offsets = null;
        self.draws = null;
        self.draw_offsets_gl = null;
    }

    pub fn deinitRenderPreviousData(self: *Chunk) void {
        if (self.prev_draw_offsets_gl) |d| self.allocator.free(d);
        self.prev_draw_offsets_gl = null;
        if (self.prev_draws) |d| self.allocator.free(d);
        self.prev_draws = null;
    }

    // findMeshes - calling context owns the resulting hash map and needs to free it.
    pub fn findMeshes(self: *Chunk) !std.AutoHashMap(usize, @Vector(4, f32)) {
        if (config.use_tracy) {
            const tracy_zone = ztracy.ZoneNC(@src(), "ChunkMeshing", 0x00_00_f0_f0);
            defer tracy_zone.End();
            var chunker = try Chunker.init(self);
            defer chunker.deinit();
            try chunker.run();
            return chunker.meshes;
        } else {
            var chunker = try Chunker.init(self);
            defer chunker.deinit();
            try chunker.run();
            return chunker.meshes;
        }
    }
};

// To use when there is no chunk, just assume fully lit.
pub const fully_lit_chunk: [chunkSize]u32 = [_]u32{0xFF_FFF_00} ** chunkSize;

const std = @import("std");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const config = @import("config");
const blecs = @import("../blecs/blecs.zig");
const gfx = @import("../gfx/gfx.zig");
const game = @import("../game.zig");
const block = @import("block.zig");
const Chunker = @import("chunker.zig");
const game_state = @import("../state.zig");
const lighting = @import("lighting_ambient_edit.zig");
const data_fetcher = @import("data_fetcher.zig");
const chunk_traverser = @import("chunk_traverser.zig");

pub const worldPosition = @import("world_position.zig");
