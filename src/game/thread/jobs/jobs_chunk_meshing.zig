const std = @import("std");
const zm = @import("zmath");
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
        var c = self.chunk;
        std.debug.print("ChunkMeshJob: meshing chunk of length {d}\n", .{c.data.len});
        c.findMeshes() catch unreachable;

        var keys = c.meshes.keyIterator();
        var draws = std.ArrayList(c_int).init(game.state.allocator);
        var draw_offsets = std.ArrayList(c_int).init(game.state.allocator);
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
        while (keys.next()) |_k| {
            const i: usize = _k.*;
            if (c.meshes.get(i)) |s| {
                const block_id: u8 = @intCast(c.data[i]);
                if (block_id == 0) std.debug.panic("why are there air blocks being meshed >:|", .{});
                const mesh_data: gfx.mesh.meshData = gfx.mesh.voxel(s) catch unreachable;
                for (mesh_data.indices, 0..) |index, ii| {
                    mesh_data.indices[ii] = index + index_offset;
                }
                draws.append(@intCast(mesh_data.indices.len)) catch unreachable;
                draw_offsets.append(@intCast(@sizeOf(c_uint) * index_offset)) catch unreachable;

                index_offset += @intCast(mesh_data.indices.len);
                const p: @Vector(4, f32) = chunk.getPositionAtIndexV(i);
                const fp: @Vector(4, f32) = .{
                    p[0] + loc[0] - 0.5,
                    p[1] + loc[1] - 0.5,
                    p[2] + loc[2] - 0.5,
                    p[3] + loc[3],
                };
                const e: chunk.ChunkElement = .{
                    .chunk_index = i,
                    .block_id = block_id,
                    .mesh_data = mesh_data,
                    .translation = fp,
                };
                c.elements.append(e) catch unreachable;
            }
        }
        self.chunk.draws = draws.toOwnedSlice() catch unreachable;
        self.chunk.draw_offsets = draw_offsets.toOwnedSlice() catch unreachable;
        for (0..self.chunk.draw_offsets.?.len) |i| {
            if (self.chunk.draw_offsets.?[i] == 0) {
                draw_offsets_gl.append(null) catch unreachable;
            } else {
                draw_offsets_gl.append(@as(
                    *anyopaque,
                    @ptrFromInt(@as(usize, @intCast(self.chunk.draw_offsets.?[i]))),
                )) catch unreachable;
            }
        }
        self.chunk.draw_offsets_gl = draw_offsets_gl.toOwnedSlice() catch unreachable;
        var msg: buffer.buffer_message = buffer.new_message(.chunk_mesh);
        buffer.set_progress(&msg, true, 1);
        buffer.put_chunk_mesh_data(msg, .{
            .world = self.world,
            .entity = self.entity,
            .chunk = self.chunk,
        }) catch unreachable;
        buffer.write_message(msg) catch unreachable;
    }
};
