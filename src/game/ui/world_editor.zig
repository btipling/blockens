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

const maxLuaScriptSize = 360_000;
const maxLuaScriptNameSize = 20;

pub const WorldEditor = struct {
    appState: *state.State,
    buf: [maxLuaScriptSize]u8,
    nameBuf: [maxLuaScriptNameSize]u8,
    luaInstance: Lua,
    codeFont: zgui.Font,
    worldOptions: std.ArrayList(data.worldOption),
    loadedWorldId: u32 = 0,

    pub fn init(appState: *state.State, robotoMonoFont: []const u8, alloc: std.mem.Allocator) !WorldEditor {
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
        var tv = WorldEditor{
            .appState = appState,
            .buf = buf,
            .nameBuf = nameBuf,
            .luaInstance = lua,
            .codeFont = codeFont,
            .worldOptions = std.ArrayList(data.worldOption).init(alloc),
        };
        try WorldEditor.listWorlds(&tv);
        return tv;
    }

    pub fn deinit(self: *WorldEditor) void {
        self.luaInstance.deinit();
    }

    pub fn draw(self: *WorldEditor, window: *glfw.Window) !void {
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
        if (zgui.begin("World Editor", .{
            .flags = .{
                .no_title_bar = false,
                .no_resize = true,
                .no_scrollbar = false,
                .no_collapse = true,
            },
        })) {
            try self.drawWorldList();
        }
        zgui.end();
        zgui.backend.draw();
    }

    fn listWorlds(self: *WorldEditor) !void {
        try self.appState.db.listWorlds(&self.worldOptions);
    }

    fn saveWorld(self: *WorldEditor) !void {
        _ = self;
    }

    fn updateWorld(self: *WorldEditor) !void {
        _ = self;
    }

    fn deleteWorld(self: *WorldEditor) !void {
        _ = self;
    }

    fn drawWorldList(self: *WorldEditor) !void {
        if (zgui.beginChild(
            "Saved Worlds",
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
                try self.listWorlds();
            }
            _ = zgui.beginListBox("##listbox", .{
                .w = 800,
                .h = 1400,
            });
            for (self.worldOptions.items) |worldOption| {
                var buffer: [maxLuaScriptNameSize + 10]u8 = undefined;
                const selectableName = try std.fmt.bufPrint(&buffer, "{d}: {s}", .{ worldOption.id, worldOption.name });
                var name: [maxLuaScriptNameSize:0]u8 = undefined;
                for (name, 0..) |_, i| {
                    if (selectableName.len <= i) {
                        name[i] = 0;
                        break;
                    }
                    name[i] = selectableName[i];
                }
                if (zgui.selectable(&name, .{})) {
                    // try self.loadTextureScriptFunc(worldOption.id);
                }
            }
            zgui.endListBox();
            if (self.loadedWorldId != 0) {
                if (zgui.button("Update world", .{
                    .w = 450,
                    .h = 100,
                })) {
                    try self.updateWorld();
                }
                if (zgui.button("Delete world", .{
                    .w = 450,
                    .h = 100,
                })) {
                    try self.deleteWorld();
                }
            }
        }
        zgui.endChild();
    }
};
