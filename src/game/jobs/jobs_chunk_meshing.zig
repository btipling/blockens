const std = @import("std");
const chunk = @import("../chunk.zig");
const blecs = @import("../blecs/blecs.zig");

pub const ChunkMeshJob = struct {
    chunk: *chunk.Chunk,
    entity: blecs.ecs.entity_t,
    world: *blecs.ecs.world_t,

    pub fn exec(self: *@This()) void {
        std.debug.print("ChunkMeshJob: meshing chunk of length {d}\n", .{self.chunk.data.len});
        self.chunk.findMeshes() catch unreachable;
        blecs.ecs.add(self.world, self.entity, blecs.components.block.NeedsMeshRendering);
    }
};
