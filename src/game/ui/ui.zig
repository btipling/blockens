const std = @import("std");
const zgui = @import("zgui");
const glfw = @import("zglfw");

pub const UI = struct {
    window: *glfw.Window,

    pub fn init(window: *glfw.Window) !UI {
        return UI{
            .window = window,
        };
    }

    pub fn draw(self: UI) !void {
        try self.drawInfo();
    }

    fn drawInfo(self: UI) !void {
        const fb_size = self.window.getFramebufferSize();
        const w: u32 = @intCast(fb_size[0]);
        const h: u32 = @intCast(fb_size[1]);
        const xPos: f32 = 50.0;
        const yPos: f32 = 50.0;
        zgui.backend.newFrame(w, h);
        zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
        zgui.setNextWindowSize(.{
            .w = 1000,
            .h = 120,
        });
        zgui.setNextItemWidth(-1);
        const style = zgui.getStyle();
        var window_bg = style.getColor(.window_bg);
        window_bg = .{ 1.00, 1.00, 1.00, 1.0 };
        style.setColor(.window_bg, window_bg);
        var text_color = style.getColor(.text);
        text_color = .{ 0.0, 0.0, 0.0, 1.00 };
        style.setColor(.text, text_color);
        if (zgui.begin("Hello, world!", .{
            .flags = .{
                .no_title_bar = true,
                .no_resize = true,
                .no_scrollbar = true,
                .no_collapse = true,
            },
        })) {
            zgui.text("Hello btzig-blockens!", .{});
            zgui.text("Press escape to quit.", .{});
        }
        zgui.end();
        zgui.backend.draw();
    }
};
