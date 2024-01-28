const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const config = @import("../config.zig");
const state = @import("../state.zig");
const data = @import("../data/data.zig");
const script = @import("../script/script.zig");
const menus = @import("menus.zig");

pub const TextureGen = struct {
    script: script.Script,
    appState: *state.State,
    buf: [script.maxLuaScriptSize]u8,
    nameBuf: [script.maxLuaScriptNameSize]u8,
    codeFont: zgui.Font,
    scriptOptions: std.ArrayList(data.scriptOption),
    loadedScriptId: i32 = 0,
    bm: menus.BuilderMenu,

    pub fn init(
        appState: *state.State,
        codeFont: zgui.Font,
        sc: script.Script,
        bm: menus.BuilderMenu,
        alloc: std.mem.Allocator,
    ) !TextureGen {
        var buf = [_]u8{0} ** script.maxLuaScriptSize;
        const nameBuf = [_]u8{0} ** script.maxLuaScriptNameSize;
        const defaultLuaScript = @embedFile("../script/lua/gen_wood_texture.lua");
        for (defaultLuaScript, 0..) |c, i| {
            buf[i] = c;
        }
        var tv = TextureGen{
            .script = sc,
            .appState = appState,
            .buf = buf,
            .nameBuf = nameBuf,
            .codeFont = codeFont,
            .scriptOptions = std.ArrayList(data.scriptOption).init(alloc),
            .bm = bm,
        };
        try TextureGen.listTextureScripts(&tv);
        return tv;
    }

    pub fn deinit(self: *TextureGen) void {
        self.scriptOptions.deinit();
    }

    pub fn draw(self: *TextureGen, window: *glfw.Window) !void {
        const xPos: f32 = 700.0;
        const yPos: f32 = 50.0;
        zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
        zgui.setNextWindowSize(.{
            .w = 2850,
            .h = 2000,
        });
        zgui.setNextItemWidth(-1);
        if (zgui.begin("Texture Editor", .{
            .flags = .{
                .no_title_bar = false,
                .no_resize = true,
                .no_scrollbar = false,
                .no_collapse = true,
            },
        })) {
            try self.bm.draw(window);
            try self.drawInput();
            zgui.sameLine(.{});
            try self.drawScriptList();
        }
        zgui.end();
    }

    fn evalTextureFunc(self: *TextureGen) !void {
        std.debug.print("texture gen: evalTextureFunc from lua\n", .{});
        const textureRGBAColor = try self.script.evalTextureFunc(self.buf);
        self.appState.app.setTextureColor(textureRGBAColor);
    }

    fn listTextureScripts(self: *TextureGen) !void {
        try self.appState.db.listTextureScripts(&self.scriptOptions);
    }

    fn loadTextureScriptFunc(self: *TextureGen, scriptId: i32) !void {
        var scriptData: data.script = undefined;
        try self.appState.db.loadTextureScript(scriptId, &scriptData);
        var buf = [_]u8{0} ** script.maxLuaScriptSize;
        var nameBuf = [_]u8{0} ** script.maxLuaScriptNameSize;
        for (scriptData.name, 0..) |c, i| {
            if (i >= script.maxLuaScriptNameSize) {
                break;
            }
            nameBuf[i] = c;
        }
        for (scriptData.script, 0..) |c, i| {
            if (i >= script.maxLuaScriptSize) {
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
                var buffer: [script.maxLuaScriptNameSize + 10]u8 = undefined;
                const selectableName = try std.fmt.bufPrint(&buffer, "{d}: {s}", .{ scriptOption.id, scriptOption.name });
                var name: [script.maxLuaScriptNameSize:0]u8 = undefined;
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
