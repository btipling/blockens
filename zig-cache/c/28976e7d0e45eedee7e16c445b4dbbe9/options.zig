pub const @"libs.zig-gamedev.libs.zgui.build.Backend" = enum {
    no_backend,
    glfw_wgpu,
    glfw_opengl3,
    win32_dx12,
};
pub const backend: @"libs.zig-gamedev.libs.zgui.build.Backend" = .glfw_opengl3;
pub const shared: bool = false;
