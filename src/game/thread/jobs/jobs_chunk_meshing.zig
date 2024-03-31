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
        var draws: [chunk.chunkSize]c_int = std.mem.zeroes([chunk.chunkSize]c_int);
        var draw_offsets: [chunk.chunkSize]c_int = std.mem.zeroes([chunk.chunkSize]c_int);
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
        const aloc: @Vector(4, f32) = loc - @as(@Vector(4, f32), @splat(0.5));
        c.deinitRenderData();
        if (config.use_tracy) ztracy.Message("setting up attribute variable buffer");

        var builder = game.state.allocator.create(
            gfx.buffer_data.AttributeBuilder,
        ) catch @panic("OOM");

        // The constraints on the buffer builder.
        const num_elements: usize = keys.len;
        const num_vertices_per_element: usize = 36;
        var current_element: usize = 0;

        // To keep track of the index offsets as everything becomes flat arrays for draw calls
        var index_offset: u32 = 0;
        var indices = game.state.allocator.alloc(u32, num_elements * num_vertices_per_element) catch @panic("OOM");

        // Create attribute builder and define the attribute variables chunk meshes use
        builder.* = gfx.buffer_data.AttributeBuilder.init(
            @intCast(num_vertices_per_element * num_elements),
            0, // set in gfx_mesh
            0,
        );
        // same order as defined in shader gen, just like gfx_mesh
        const pos_loc: u32 = builder.defineFloatAttributeValue(3);
        const tc_loc: u32 = builder.defineFloatAttributeValue(2);
        const nor_loc: u32 = builder.defineFloatAttributeValue(3);
        const block_data_loc: u32 = builder.defineFloatAttributeValue(2);
        const attr_trans_loc: u32 = builder.defineFloatAttributeValue(4);
        builder.initBuffer();

        if (config.use_tracy) ztracy.Message("iterating through meshes");
        while (keys.next()) |_k| {
            if (config.use_tracy) ztracy.Message("iterating through a mesh");
            const i: usize = _k.*;

            // Scale and block id are the magic that build chunks. Lighting, transparency and orientation will probably be needed too.
            const s = c.meshes.get(i) orelse std.debug.panic("expected scale from mesh", .{});
            const block_id: u8 = @intCast(c.data[i]);
            if (block_id == 0) std.debug.panic("why are there air blocks being meshed >:|", .{});

            // Get the possibly cashed mesh data to build the buffer with.
            const mesh_data: gfx.mesh.meshDataVoxels = gfx.mesh.voxel_mesh_creator.voxel(s) catch @panic("nope");

            // Build the data used for ebo and to make draw calls with.
            for (mesh_data.indices, 0..) |index, ii| {
                indices[index_offset + ii] = index_offset + index;
            }
            draws[current_element] = @intCast(mesh_data.indices.len);
            draw_offsets[current_element] = @intCast(@sizeOf(c_uint) * index_offset);
            index_offset += @intCast(mesh_data.indices.len);

            // Setup for writing attribute variables to gfx buffer
            const cfp: @Vector(4, f32) = chunk.getPositionAtIndexV(i);
            const translation: @Vector(4, f32) = .{
                cfp[0] + aloc[0],
                cfp[1] + aloc[1],
                cfp[2] + aloc[2],
                cfp[3],
            };

            if (config.use_tracy) ztracy.Message("adding multidraw vertex to vbo buffer builder");
            const vertex_offset = num_vertices_per_element * current_element;
            for (0..mesh_data.positions.len) |ii| {
                const vertex_index: usize = ii + vertex_offset;
                {
                    const p = mesh_data.positions[ii];
                    builder.addFloatAtLocation(pos_loc, &p, vertex_index);
                }
                {
                    const t = mesh_data.texcoords[ii];
                    builder.addFloatAtLocation(tc_loc, &t, vertex_index);
                }
                {
                    const n = mesh_data.normals[ii];
                    builder.addFloatAtLocation(nor_loc, &n, vertex_index);
                }
                {
                    const bi = block_id;
                    const block_index: f32 = @floatFromInt(game.state.ui.data.texture_atlas_block_index[@intCast(bi)]);
                    const num_blocks: f32 = @floatFromInt(game.state.ui.data.texture_atlas_num_blocks);
                    const bd: [2]f32 = [_]f32{ block_index, num_blocks };
                    builder.addFloatAtLocation(block_data_loc, &bd, vertex_index);
                }
                {
                    const atr_data: [4]f32 = translation;
                    builder.addFloatAtLocation(attr_trans_loc, &atr_data, vertex_index);
                }
                builder.nextVertex();
            }
            current_element += 1;
        }
        // Attach buffer builder and indicies on chunk to pass on to gfx_mesh, which will clean it up.
        c.attr_builder = builder;
        c.indices = indices;
        if (config.use_tracy) ztracy.Message("done iterating through meshes");

        // The draws are attached to the chunk and used for drawing calls
        {
            const c_draws = game.state.allocator.alloc(c_int, current_element) catch @panic("OOM");
            @memcpy(c_draws, draws[0..current_element]);
            c.draws = c_draws;
            const c_draws_offsets = game.state.allocator.alloc(c_int, current_element) catch @panic("OOM");
            @memcpy(c_draws_offsets, draw_offsets[0..current_element]);
            c.draw_offsets = c_draws_offsets;
            for (0..current_element) |i| {
                if (c.draw_offsets.?[i] == 0) {
                    draw_offsets_gl.append(null) catch @panic("OOM");
                } else {
                    draw_offsets_gl.append(@as(
                        *anyopaque,
                        @ptrFromInt(@as(usize, @intCast(c.draw_offsets.?[i]))),
                    )) catch @panic("OOM");
                }
            }
            c.draw_offsets_gl = draw_offsets_gl.toOwnedSlice() catch @panic("OOM");
        }

        // Signal via buffer message that the job is done.
        var msg: buffer.buffer_message = buffer.new_message(.chunk_mesh);
        buffer.set_progress(&msg, true, 1);
        buffer.put_chunk_mesh_data(msg, .{
            .world = self.world,
            .entity = self.entity,
            .chunk = c,
        }) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("nope");
        if (config.use_tracy) ztracy.Message("done with mesh job");
    }
};
