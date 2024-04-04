pub const shadergen = @import("shadergen.zig");
pub const buffer_data = @import("buffer_data.zig");
pub const constants = @import("gfx_constants.zig");
pub const mesh = @import("mesh.zig");
pub const cltf = @import("cltf_mesh.zig");
pub const gl = @import("gl.zig");

pub fn init() void {
    mesh.init();
}

pub fn deinit() void {
    mesh.deinit();
}

pub const Gfx = struct {};
