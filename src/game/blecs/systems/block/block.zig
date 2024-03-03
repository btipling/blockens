const meshing = @import("block_meshing.zig");
const rendering = @import("block_rendering.zig");

pub fn init() void {
    meshing.init();
    rendering.init();
}
