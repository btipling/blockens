const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const config = @import("../config.zig");
const position = @import("../position.zig");
const shape = @import("../shape/shape.zig");
const state = @import("../state.zig");
const data = @import("../data/data.zig");
const script = @import("../script/script.zig");
const builder_menu = @import("builder_menu.zig");

const maxWorldSizeName = 20;

pub const ChunkGenerator = struct {
    script: script.Script,
    appState: *state.State,
    alloc: std.mem.Allocator,
    buf: [script.maxLuaScriptSize]u8,
    codeFont: zgui.Font,
    bm: builder_menu.BuilderMenu,

    pub fn init(
        appState: *state.State,
        codeFont: zgui.Font,
        sc: script.Script,
        bm: builder_menu.BuilderMenu,
        alloc: std.mem.Allocator,
    ) !ChunkGenerator {
        var buf = [_]u8{0} ** script.maxLuaScriptSize;
        const defaultLuaScript = @embedFile("../script/lua/chunk_gen_hole.lua");
        for (defaultLuaScript, 0..) |c, i| {
            buf[i] = c;
        }
        const tv = ChunkGenerator{
            .script = sc,
            .appState = appState,
            .alloc = alloc,
            .buf = buf,
            .codeFont = codeFont,
            .bm = bm,
        };
        return tv;
    }

    pub fn deinit(self: *ChunkGenerator) void {
        _ = self;
    }

    pub fn draw(self: *ChunkGenerator, window: *glfw.Window) !void {
        if (!self.appState.app.showChunkGeneratorUI) {
            return;
        }
        const fb_size = window.getFramebufferSize();
        const w: u32 = @intCast(fb_size[0]);
        const h: u32 = @intCast(fb_size[1]);
        zgui.backend.newFrame(w, h);
        const xPos: f32 = 1700.0;
        const yPos: f32 = 50.0;
        zgui.setNextWindowFocus();
        zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
        zgui.setNextWindowSize(.{
            .w = 1850,
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
        if (zgui.begin("Chunk Generator", .{
            .flags = .{
                .no_title_bar = false,
                .no_resize = true,
                .no_scrollbar = false,
                .no_collapse = true,
            },
        })) {
            try self.bm.draw(window);
            try self.drawControls();
            try self.drawInput();
        }
        zgui.end();
        zgui.backend.draw();
    }

    fn drawControls(self: *ChunkGenerator) !void {
        if (zgui.beginChild(
            "Create World",
            .{
                .w = 850,
                .h = 200,
                .border = false,
            },
        )) {
            zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
            const style = zgui.getStyle();
            var text_color = style.getColor(.text);
            text_color = .{ 0.0, 0.0, 0.0, 1.00 };
            style.setColor(.text, text_color);
            if (zgui.button("Generate random chunk", .{
                .w = 700,
                .h = 100,
            })) {
                try self.generateRandomChunk();
            }
            zgui.popStyleVar(.{ .count = 1 });
        }
        zgui.endChild();
    }

    fn drawInput(self: *ChunkGenerator) !void {
        if (zgui.beginChild(
            "script_input",
            .{
                .w = 2000,
                .h = 1500,
                .border = true,
            },
        )) {
            zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
            const style = zgui.getStyle();
            var text_color = style.getColor(.text);
            text_color = .{ 0.0, 0.0, 0.0, 1.00 };
            style.setColor(.text, text_color);
            if (zgui.button("Generate chunk", .{
                .w = 450,
                .h = 100,
            })) {
                try self.evalChunkFunc();
            }
            zgui.popStyleVar(.{ .count = 1 });
            zgui.pushFont(self.codeFont);
            _ = zgui.inputTextMultiline(" ", .{
                .buf = self.buf[0..],
                .w = 1984,
                .h = 1840,
            });
            zgui.popFont();
        }
        zgui.endChild();
    }

    fn generateRandomChunk(self: *ChunkGenerator) !void {
        self.appState.demoView.clearChunks();
        try self.appState.demoView.initChunks(self.appState);
        const demoChunk = self.appState.demoView.randomChunk(9001);
        try self.appState.demoView.initChunk(demoChunk, position.Position{ .x = 0, .y = 0, .z = 0 });
    }

    fn evalChunkFunc(self: *ChunkGenerator) !void {
        std.debug.print("chunk gen: evalChunkFunc from lua\n", .{});
        self.appState.demoView.clearChunks();
        try self.appState.demoView.initChunks(self.appState);
        const demoChunk = try self.script.evalChunkFunc(self.buf);
        try self.appState.demoView.initChunk(demoChunk, position.Position{ .x = 0, .y = 0, .z = 0 });
    }
};
