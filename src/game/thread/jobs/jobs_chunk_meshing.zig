const std = @import("std");
const chunk = @import("../../chunk.zig");
const blecs = @import("../../blecs/blecs.zig");
const buffer = @import("../buffer.zig");

pub const ChunkMeshJob = struct {
    chunk: *chunk.Chunk,
    entity: blecs.ecs.entity_t,
    world: *blecs.ecs.world_t,

    pub fn exec(self: *@This()) void {
        std.debug.print("ChunkMeshJob: meshing chunk of length {d}\n", .{self.chunk.data.len});
        self.chunk.findMeshes() catch unreachable;
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
