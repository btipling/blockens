const gui = @import("gui.zig");

pub fn initWithGlSlVersion(
    window: *const anyopaque, // zglfw.Window
    glsl_version: ?[*c]const u8, // e.g. "#version 130"
) void {
    if (!ImGui_ImplGlfw_InitForOpenGL(window, true)) {
        unreachable;
    }

    if (glsl_version) |v| {
        ImGui_ImplOpenGL3_Init(v);
    } else {
        ImGui_ImplOpenGL3_Init(null);
    }
}

pub fn init(
    window: *const anyopaque, // zglfw.Window
) void {
    initWithGlSlVersion(window, null);
}

pub fn deinit() void {
    ImGui_ImplGlfw_Shutdown();
    ImGui_ImplOpenGL3_Shutdown();
}

pub fn newFrame(fb_width: u32, fb_height: u32) void {
    ImGui_ImplGlfw_NewFrame();
    ImGui_ImplOpenGL3_NewFrame();

    gui.io.setDisplaySize(@as(f32, @floatFromInt(fb_width)), @as(f32, @floatFromInt(fb_height)));
    gui.io.setDisplayFramebufferScale(1.0, 1.0);

    gui.newFrame();
}

pub fn draw() void {
    gui.render();
    ImGui_ImplOpenGL3_RenderDrawData(gui.getDrawData());
}

extern fn ImGui_ImplGlfw_InitForOpenGL(window: *const anyopaque, install_callbacks: bool) bool;
extern fn ImGui_ImplGlfw_NewFrame() void;
extern fn ImGui_ImplGlfw_Shutdown() void;
extern fn ImGui_ImplOpenGL3_Init(glsl_version: [*c]const u8) void;
extern fn ImGui_ImplOpenGL3_Shutdown() void;
extern fn ImGui_ImplOpenGL3_NewFrame() void;
extern fn ImGui_ImplOpenGL3_RenderDrawData(data: *const anyopaque) void;
