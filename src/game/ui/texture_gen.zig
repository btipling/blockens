const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const ziglua = @import("ziglua");
const config = @import("../config.zig");
const shape = @import("../shape.zig");
const state = @import("../state.zig");

const Lua = ziglua.Lua;

const robotoMonoFont = @embedFile("../assets/fonts/Roboto_Mono/RobotoMono-Regular.ttf");

const maxLuaScriptSize = 360_000;
const maxLuaScriptNameSize = 10;

pub const TextureGen = struct {
    appState: *state.State,
    buf: [maxLuaScriptSize]u8,
    nameBuf: [maxLuaScriptNameSize]u8,
    luaInstance: Lua,
    codeFont: zgui.Font,

    pub fn init(appState: *state.State, alloc: std.mem.Allocator) !TextureGen {
        var lua: Lua = try Lua.init(alloc);
        lua.openLibs();
        var buf = [_]u8{0} ** maxLuaScriptSize;
        const nameBuf = [_]u8{0} ** maxLuaScriptNameSize;
        const defaultLuaScript = @embedFile("../assets/lua/gen_texture_brightness.lua");
        for (defaultLuaScript, 0..) |c, i| {
            buf[i] = c;
        }
        const font_size = 40.0;
        const codeFont = zgui.io.addFontFromMemory(robotoMonoFont, std.math.floor(font_size * 1.1));
        return TextureGen{
            .appState = appState,
            .buf = buf,
            .nameBuf = nameBuf,
            .luaInstance = lua,
            .codeFont = codeFont,
        };
    }

    pub fn deinit(self: *TextureGen) void {
        self.luaInstance.deinit();
    }

    pub fn draw(self: *TextureGen, window: *glfw.Window) !void {
        try self.drawInput(window);
    }

    fn evalTextureFunc(self: *TextureGen) !void {
        std.debug.print("evalTextureFunc from lua\n", .{});
        var luaCode: [maxLuaScriptSize]u8 = [_]u8{0} ** maxLuaScriptSize;
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
        _ = self.luaInstance.getGlobal("textures") catch |err| {
            std.log.err("Failed to get global textures. {}", .{err});
            return;
        };
        if (self.luaInstance.isTable(-1) == false) {
            std.log.err("textures is not a table", .{});
            return;
        } else {
            std.debug.print("textures is a table\n", .{});
        }
        self.luaInstance.len(-1);
        const tableSize = self.luaInstance.toInteger(-1) catch {
            std.log.err("Failed to get table size", .{});
            return;
        };
        const ts = @as(usize, @intCast(tableSize));
        std.debug.print("table size: {d}\n", .{ts});
        self.luaInstance.pop(1);
        if (self.luaInstance.isTable(-1) == false) {
            std.log.err("textures is not back to a table", .{});
            return;
        } else {
            std.debug.print("textures is back to a table\n", .{});
        }
        var textureRGBAColor: [shape.RGBAColorTextureSize]gl.Uint = [_]gl.Uint{0} ** shape.RGBAColorTextureSize;
        for (1..(ts + 1)) |i| {
            _ = self.luaInstance.rawGetIndex(-1, @intCast(i));
            const color = self.luaInstance.toInteger(-1) catch {
                std.log.err("Failed to get color", .{});
                return;
            };
            textureRGBAColor[i - 1] = @as(gl.Uint, @intCast(color));
            self.luaInstance.pop(1);
        }
        self.appState.app.setTextureColor(textureRGBAColor);
    }

    fn saveTextureFunc(self: *TextureGen) !void {
        std.debug.print("saveTextureFunc from lua with name {s} \n", .{self.nameBuf});
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
        zgui.setItemDefaultFocus();
        zgui.setNextItemWidth(-1);
        const style = zgui.getStyle();
        var window_bg = style.getColor(.window_bg);
        window_bg = .{ 1.00, 1.00, 1.00, 1.0 };
        style.setColor(.window_bg, window_bg);
        var text_color = style.getColor(.text);
        text_color = .{ 0.0, 0.0, 0.0, 1.00 };
        const title_color = .{ 1.0, 1.0, 1.0, 1.00 };
        style.setColor(.text, title_color);
        zgui.setNextWindowFocus();
        if (zgui.begin("Create a block texture!", .{
            .flags = .{
                .no_title_bar = false,
                .no_resize = true,
                .no_scrollbar = false,
                .no_collapse = true,
            },
        })) {
            zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
            style.setColor(.text, text_color);
            if (zgui.button("Change texture", .{
                .w = 450,
                .h = 100,
            })) {
                try self.evalTextureFunc();
            }
            zgui.sameLine(.{});
            if (zgui.button("Save texture script", .{
                .w = 600,
                .h = 100,
            })) {
                try self.saveTextureFunc();
            }
            zgui.popStyleVar(.{ .count = 1 });
            zgui.sameLine(.{});
            zgui.pushFont(self.codeFont);
            zgui.pushItemWidth(1000);
            _ = zgui.inputTextWithHint("Script name", .{
                .buf = self.nameBuf[0..],
                .hint = "block_script",
            });
            zgui.popItemWidth();
            _ = zgui.inputTextMultiline(" ", .{
                .buf = self.buf[0..],
                .w = 2400,
                .h = 1800,
            });
            zgui.popFont();
        }
        zgui.end();
        zgui.backend.draw();
    }
};
