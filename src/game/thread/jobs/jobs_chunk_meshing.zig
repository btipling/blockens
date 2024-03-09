const std = @import("std");
const chunk = @import("../../chunk.zig");
const blecs = @import("../../blecs/blecs.zig");

pub const ChunkMeshJob = struct {
    chunk: *chunk.Chunk,
    entity: blecs.ecs.entity_t,
    world: *blecs.ecs.world_t,

    pub fn exec(self: *@This()) void {
        std.debug.print("ChunkMeshJob: meshing chunk of length {d}\n", .{self.chunk.data.len});
        self.chunk.findMeshes() catch unreachable;
        var i: usize = 0;
        while (true) {
            i += 1;
            if (i > 1000) return;
            if (blecs.ecs.is_deferred(self.world)) {
                std.time.sleep(10000);
            }
            blecs.ecs.add(self.world, self.entity, blecs.components.block.NeedsMeshRendering);
            return;
        }
    }
};
