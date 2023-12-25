const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const ziglua = @import("ziglua");
const config = @import("../config.zig");
const shape = @import("../shape.zig");
const state = @import("../state.zig");
const data = @import("../data/data.zig");

const Lua = ziglua.Lua;

const robotoMonoFont = @embedFile("../assets/fonts/Roboto_Mono/RobotoMono-Regular.ttf");

const maxLuaScriptSize = 360_000;
const maxLuaScriptNameSize = 20;

pub const TextureGen = struct {
    appState: *state.State,
    buf: [maxLuaScriptSize]u8,
    nameBuf: [maxLuaScriptNameSize]u8,
    luaInstance: Lua,
    codeFont: zgui.Font,
    scriptOptions: std.ArrayList(data.scriptOption),
    loadedScriptId: u32 = 0,

    pub fn init(appState: *state.State, alloc: std.mem.Allocator) !TextureGen {
        var lua: Lua = try Lua.init(alloc);
        lua.openLibs();
        var buf = [_]u8{0} ** maxLuaScriptSize;
        const nameBuf = [_]u8{0} ** maxLuaScriptNameSize;
        const defaultLuaScript = @embedFile("../assets/lua/gen_wood_texture.lua");
        for (defaultLuaScript, 0..) |c, i| {
            buf[i] = c;
        }
        const font_size = 40.0;
        const codeFont = zgui.io.addFontFromMemory(robotoMonoFont, std.math.floor(font_size * 1.1));
        var tv = TextureGen{
            .appState = appState,
            .buf = buf,
            .nameBuf = nameBuf,
            .luaInstance = lua,
            .codeFont = codeFont,
            .scriptOptions = std.ArrayList(data.scriptOption).init(alloc),
        };
        try TextureGen.listTextureScripts(&tv);
        return tv;
    }

    pub fn deinit(self: *TextureGen) void {
        self.luaInstance.deinit();
    }

    pub fn draw(self: *TextureGen, window: *glfw.Window) !void {
        const fb_size = window.getFramebufferSize();
        const w: u32 = @intCast(fb_size[0]);
        const h: u32 = @intCast(fb_size[1]);
        zgui.backend.newFrame(w, h);
        const xPos: f32 = 700.0;
        const yPos: f32 = 50.0;
        zgui.setNextWindowFocus();
        zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
        zgui.setNextWindowSize(.{
            .w = 2850,
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
        if (zgui.begin("Create a block texture!", .{
            .flags = .{
                .no_title_bar = false,
                .no_resize = true,
                .no_scrollbar = false,
                .no_collapse = true,
            },
        })) {
            try self.drawInput();
            zgui.sameLine(.{});
            try self.drawScriptList();
        }
        zgui.end();
        zgui.backend.draw();
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

    fn listTextureScripts(self: *TextureGen) !void {
        try self.appState.db.listTextureScripts(&self.scriptOptions);
    }

    fn loadTextureScriptFunc(self: *TextureGen, scriptId: u32) !void {
        var scriptData: data.script = undefined;
        try self.appState.db.loadTextureScript(scriptId, &scriptData);
        var buf = [_]u8{0} ** maxLuaScriptSize;
        var nameBuf = [_]u8{0} ** maxLuaScriptNameSize;
        for (scriptData.name, 0..) |c, i| {
            if (i >= maxLuaScriptNameSize) {
                break;
            }
            nameBuf[i] = c;
        }
        for (scriptData.script, 0..) |c, i| {
            if (i >= maxLuaScriptSize) {
                break;
            }
            buf[i] = c;
        }
        self.buf = buf;
        self.nameBuf = nameBuf;
        try self.evalTextureFunc();
        self.loadedScriptId = scriptId;
    }

    fn saveTextureScriptFunc(self: *TextureGen) !void {
        const n = std.mem.indexOf(u8, &self.nameBuf, &([_]u8{0}));
        if (n) |i| {
            if (i < 3) {
                std.log.err("Script name is too short", .{});
                return;
            }
        }
        try self.appState.db.saveTextureScript(&self.nameBuf, &self.buf);
        try self.listTextureScripts();
    }

    fn updateTextureScriptFunc(self: *TextureGen) !void {
        const n = std.mem.indexOf(u8, &self.nameBuf, &([_]u8{0}));
        if (n) |i| {
            if (i < 3) {
                std.log.err("Script name is too short", .{});
                return;
            }
        }
        try self.appState.db.updateTextureScript(self.loadedScriptId, &self.nameBuf, &self.buf);
        try self.listTextureScripts();
        try self.loadTextureScriptFunc(self.loadedScriptId);
    }

    fn deleteTextureScriptFunc(self: *TextureGen) !void {
        try self.appState.db.deleteTextureScript(self.loadedScriptId);
        try self.listTextureScripts();
        self.loadedScriptId = 0;
    }

    fn drawInput(self: *TextureGen) !void {
        if (zgui.beginChild(
            "script_input",
            .{
                .w = 2000,
                .h = 2000,
                .border = true,
            },
        )) {
            zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
            const style = zgui.getStyle();
            var text_color = style.getColor(.text);
            text_color = .{ 0.0, 0.0, 0.0, 1.00 };
            style.setColor(.text, text_color);
            if (zgui.button("Change texture", .{
                .w = 450,
                .h = 100,
            })) {
                try self.evalTextureFunc();
            }
            zgui.sameLine(.{});
            if (zgui.button("Save new texture script", .{
                .w = 650,
                .h = 100,
            })) {
                try self.saveTextureScriptFunc();
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
                .w = 1984,
                .h = 1840,
            });
            zgui.popFont();
        }
        zgui.endChild();
    }

    fn drawScriptList(self: *TextureGen) !void {
        if (zgui.beginChild(
            "Saved scripts",
            .{
                .w = 850,
                .h = 1800,
                .border = true,
            },
        )) {
            if (zgui.button("Refresh list", .{
                .w = 450,
                .h = 100,
            })) {
                try self.listTextureScripts();
            }
            _ = zgui.beginListBox("##listbox", .{
                .w = 800,
                .h = 1400,
            });
            for (self.scriptOptions.items) |scriptOption| {
                var buffer: [maxLuaScriptNameSize + 10]u8 = undefined;
                const selectableName = try std.fmt.bufPrint(&buffer, "{d}: {s}", .{ scriptOption.id, scriptOption.name });
                var name: [maxLuaScriptNameSize:0]u8 = undefined;
                for (name, 0..) |_, i| {
                    if (selectableName.len <= i) {
                        name[i] = 0;
                        break;
                    }
                    name[i] = selectableName[i];
                }
                if (zgui.selectable(&name, .{})) {
                    try self.loadTextureScriptFunc(scriptOption.id);
                }
            }
            zgui.endListBox();
            if (self.loadedScriptId != 0) {
                if (zgui.button("Update script", .{
                    .w = 450,
                    .h = 100,
                })) {
                    try self.updateTextureScriptFunc();
                }
                if (zgui.button("Delete script", .{
                    .w = 450,
                    .h = 100,
                })) {
                    try self.deleteTextureScriptFunc();
                }
            }
        }
        zgui.endChild();
    }
};
