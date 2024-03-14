const std = @import("std");
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
        while (keys.next()) |_k| {
            const i: usize = _k.*;
            if (c.meshes.get(i)) |s| {
                const block_id: u8 = @intCast(c.data[i]);
                const mesh_data: gfx.mesh.meshData = gfx.mesh.voxel(s) catch unreachable;
                const e: chunk.ChunkElement = .{
                    .chunk_index = i,
                    .block_id = block_id,
                    .mesh_data = mesh_data,
                };
                c.elements.append(e) catch unreachable;
            }
        }

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
