const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const config = @import("../config.zig");

pub const UI = struct {
    window: *glfw.Window,
    Game: Game,
    TextureGen: TextureGen,

    pub fn init(window: *glfw.Window) !UI {
        return UI{
            .window = window,
            .Game = Game{},
            .TextureGen = try TextureGen.init(),
        };
    }

    pub fn drawGame(self: *UI) !void {
        try self.Game.draw(self.window);
    }

    pub fn drawTextureGen(self: *UI) !void {
        try self.TextureGen.draw(self.window);
        self.window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.normal);
    }
};

pub fn handleInput(_: *zgui.InputTextCallbackData) i32 {
    std.debug.print("handleInput\n", .{});
    return 0;
}

pub const TextureGen = struct {
    buf: [1000]u8,

    pub fn init() !TextureGen {
        return TextureGen{
            .buf = [_]u8{0} ** 1000,
        };
    }

    fn draw(self: *TextureGen, window: *glfw.Window) !void {
        try self.drawInput(window);
    }

    fn drawInput(self: *TextureGen, window: *glfw.Window) !void {
        const fb_size = window.getFramebufferSize();
        const w: u32 = @intCast(fb_size[0]);
        const h: u32 = @intCast(fb_size[1]);
        const xPos: f32 = 1000.0;
        const yPos: f32 = 50.0;
        zgui.backend.newFrame(w, h);
        zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
        zgui.setNextWindowSize(.{
            .w = 2500,
            .h = 2000,
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
            zgui.text("Create a block texture!", .{});
            if (zgui.button("Change texture", .{
                .w = 500,
                .h = 100,
            })) {
                std.debug.print("color button pressed: {s}\n", .{self.buf});
            }
            _ = zgui.inputTextMultiline(" ", .{
                .buf = self.buf[0..],
                .w = 2400,
                .h = 1800,
                .callback = handleInput,
            });
        }
        zgui.setKeyboardFocusHere(0);
        zgui.end();
        zgui.backend.draw();
    }
};

pub const Game = struct {
    pub fn draw(self: Game, window: *glfw.Window) !void {
        try self.drawInfo(window);
    }

    fn drawInfo(_: Game, window: *glfw.Window) !void {
        const fb_size = window.getFramebufferSize();
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
