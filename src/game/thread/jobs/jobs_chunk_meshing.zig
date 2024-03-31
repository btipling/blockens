const std = @import("std");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const config = @import("config");
const chunk = @import("../../chunk.zig");
const game = @import("../../game.zig");
const blecs = @import("../../blecs/blecs.zig");
const buffer = @import("../buffer.zig");
const gfx = @import("../../gfx/gfx.zig");

pub const ChunkMeshJob = struct {
    chunk: *chunk.Chunk,
    entity: blecs.ecs.entity_t,
    world: *blecs.ecs.world_t,

    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            ztracy.SetThreadName("ChunkMeshJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "ChunkMeshJob", 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.mesh();
        } else {
            self.mesh();
        }
    }

    pub fn mesh(self: *@This()) void {
        if (config.use_tracy) ztracy.Message("starting mesh");
        var c = self.chunk;
        c.mutex.lock();
        defer c.mutex.unlock();
        c.deinitMeshes();
        if (config.use_tracy) ztracy.Message("starting finding meshes");
        c.findMeshes() catch unreachable;
        if (config.use_tracy) ztracy.Message("done finding meshes");
        var keys = c.meshes.keyIterator();
        // var draws = std.ArrayList(c_int).init(game.state.allocator);
        var draws: [chunk.chunkSize]c_int = std.mem.zeroes([chunk.chunkSize]c_int);
        var elements_size: usize = 0;
        var draw_offsets: [chunk.chunkSize]c_int = std.mem.zeroes([chunk.chunkSize]c_int);
        // var draw_offsets = std.ArrayList(c_int).init(game.state.allocator);
        var draw_offsets_gl = std.ArrayList(?*const anyopaque).init(game.state.allocator);
        const cp = c.wp.vecFromWorldPosition();
        var loc: @Vector(4, f32) = undefined;
        if (c.is_settings) {
            loc = .{ -32, 0, -32, 0 };
        } else {
            loc = .{
                cp[0] * chunk.chunkDim,
                cp[1] * chunk.chunkDim,
                cp[2] * chunk.chunkDim,
                0,
            };
        }
        var index_offset: u32 = 0;
        const aloc: @Vector(4, f32) = loc - @as(@Vector(4, f32), @splat(0.5));
        c.deinitRenderData();
        if (config.use_tracy) ztracy.Message("iterating through meshes");
        while (keys.next()) |_k| {
            if (config.use_tracy) ztracy.Message("iterating through a mesh");
            const i: usize = _k.*;
            if (c.meshes.get(i)) |s| {
                const block_id: u8 = @intCast(c.data[i]);
                if (block_id == 0) std.debug.panic("why are there air blocks being meshed >:|", .{});
                const mesh_data: gfx.mesh.meshData = gfx.mesh.voxel(s) catch @panic("nope");
                for (mesh_data.indices, 0..) |index, ii| {
                    mesh_data.indices[ii] = index + index_offset;
                }
                draws[elements_size] = @intCast(mesh_data.indices.len);
                draw_offsets[elements_size] = @intCast(@sizeOf(c_uint) * index_offset);

                index_offset += @intCast(mesh_data.indices.len);
                const p: @Vector(4, f32) = chunk.getPositionAtIndexV(i);
                const fp: @Vector(4, f32) = .{
                    p[0] + aloc[0],
                    p[1] + aloc[1],
                    p[2] + aloc[2],
                    p[3],
                };
                const e: chunk.ChunkElement = .{
                    .chunk_index = i,
                    .block_id = block_id,
                    .mesh_data = mesh_data,
                    .translation = fp,
                };
                c.elements.append(e) catch @panic("OOM");
                elements_size += 1;
            }
        }
        if (config.use_tracy) ztracy.Message("done iterating through meshes");

        const c_draws = game.state.allocator.alloc(c_int, elements_size) catch @panic("OOM");
        @memcpy(c_draws, draws[0..elements_size]);
        self.chunk.draws = c_draws;
        const c_draws_offsets = game.state.allocator.alloc(c_int, elements_size) catch @panic("OOM");
        @memcpy(c_draws_offsets, draw_offsets[0..elements_size]);
        self.chunk.draw_offsets = c_draws_offsets;
        for (0..elements_size) |i| {
            if (self.chunk.draw_offsets.?[i] == 0) {
                draw_offsets_gl.append(null) catch @panic("OOM");
            } else {
                draw_offsets_gl.append(@as(
                    *anyopaque,
                    @ptrFromInt(@as(usize, @intCast(self.chunk.draw_offsets.?[i]))),
                )) catch @panic("OOM");
            }
        }
        self.chunk.draw_offsets_gl = draw_offsets_gl.toOwnedSlice() catch @panic("OOM");
        var msg: buffer.buffer_message = buffer.new_message(.chunk_mesh);
        buffer.set_progress(&msg, true, 1);
        buffer.put_chunk_mesh_data(msg, .{
            .world = self.world,
            .entity = self.entity,
            .chunk = self.chunk,
        }) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("nope");
        if (config.use_tracy) ztracy.Message("done with mesh job");
    }
};
