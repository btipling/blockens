pub fn init() void {
    meshing.init();
    mesh_rendering.init();
    picking.init();
    chunk_update.init();
}

const meshing = @import("block_meshing.zig");
const mesh_rendering = @import("block_mesh_rendering.zig");
const picking = @import("block_picking.zig");
const chunk_update = @import("block_chunk_update.zig");
