const meshing = @import("block_meshing.zig");
const mesh_rendering = @import("block_mesh_rendering.zig");
const instance_rendering = @import("block_instance_rendering.zig");

pub fn init() void {
    meshing.init();
    mesh_rendering.init();
    instance_rendering.init();
}
