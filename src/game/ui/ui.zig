const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const config = @import("../config.zig");
const ziglua = @import("ziglua");

const Lua = ziglua.Lua;

pub const UI = struct {
    window: *glfw.Window,
    Game: Game,
    TextureGen: TextureGen,

    pub fn init(window: *glfw.Window, alloc: std.mem.Allocator) !UI {
        return UI{
            .window = window,
            .Game = Game{},
            .TextureGen = try TextureGen.init(alloc),
        };
    }

    pub fn deinit(self: *UI) void {
        self.TextureGen.deinit();
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
    luaInstance: Lua,

    fn init(alloc: std.mem.Allocator) !TextureGen {
        var lua: Lua = try Lua.init(alloc);

        // Add an integer to the Lua stack and retrieve it
        lua.pushInteger(99);
        lua.openLibs();
        std.debug.print("{}\n", .{try lua.toInteger(1)});
        return TextureGen{
            .buf = [_]u8{0} ** 1000,
            .luaInstance = lua,
        };
    }

    fn deinit(self: *TextureGen) void {
        self.luaInstance.deinit();
    }

    fn draw(self: *TextureGen, window: *glfw.Window) !void {
        try self.drawInput(window);
    }

    fn evalTextureFunc(self: *TextureGen) !void {
        std.debug.print("evalTextureFunc from lua\n", .{});
        var luaCode: [1000]u8 = [_]u8{0} ** 1000;
        var nullIndex: usize = 0;
        for (self.buf) |c| {
            if (c == 0) {
                break;
            }
            luaCode[nullIndex] = c;
            nullIndex += 1;
        }
        const luaCString: [:0]const u8 = luaCode[0..nullIndex :0];
        self.luaInstance.doString(luaCString) catch {
            std.log.err("Failed to eval lua code from string {s}.", .{luaCString});
            return;
        };
        _ = self.luaInstance.getGlobal("hello_world") catch |err| {
            std.log.err("Failed to get global hello_world. {}", .{err});
            return;
        };
        self.luaInstance.protectedCall(0, 0, 0) catch {
            const op = try self.luaInstance.toBytes(-1);
            std.log.err("Failed to call hello_world {s}", .{op});
            return;
        };
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
                try self.evalTextureFunc();
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
