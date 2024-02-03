const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const config = @import("../config.zig");
const shape = @import("../shape/shape.zig");
const state = @import("../state/state.zig");
const chunk = @import("../chunk.zig");
const data = @import("../data/data.zig");
const script = @import("../script/script.zig");
const menus = @import("menus.zig");

const maxWorldSizeName = 20;

pub const ChunkGenerator = struct {
    script: script.Script,
    appState: *state.State,
    alloc: std.mem.Allocator,
    buf: [script.maxLuaScriptSize]u8,
    nameBuf: [script.maxLuaScriptNameSize]u8,
    chunkXBuf: [5]u8,
    chunkYBuf: [5]u8,
    chunkZBuf: [5]u8,
    codeFont: zgui.Font,
    scriptOptions: std.ArrayList(data.chunkScriptOption),
    loadedScriptId: i32 = 0,
    scriptColor: [3]f32,
    bm: menus.BuilderMenu,

    pub fn init(
        appState: *state.State,
        codeFont: zgui.Font,
        sc: script.Script,
        bm: menus.BuilderMenu,
        alloc: std.mem.Allocator,
    ) !ChunkGenerator {
        var buf = [_]u8{0} ** script.maxLuaScriptSize;
        const nameBuf = [_]u8{0} ** script.maxLuaScriptNameSize;
        const defaultLuaScript = @embedFile("../script/lua/chunk_gen_surface.lua");
        for (defaultLuaScript, 0..) |c, i| {
            buf[i] = c;
        }
        var defaultPos: [5]u8 = [_]u8{0} ** 5;
        defaultPos[0] = '0';
        var cg = ChunkGenerator{
            .script = sc,
            .appState = appState,
            .alloc = alloc,
            .buf = buf,
            .nameBuf = nameBuf,
            .chunkXBuf = defaultPos,
            .chunkYBuf = defaultPos,
            .chunkZBuf = defaultPos,
            .codeFont = codeFont,
            .scriptOptions = std.ArrayList(data.chunkScriptOption).init(alloc),
            .scriptColor = .{ 1.0, 0.0, 0.0 },
            .bm = bm,
        };
        try ChunkGenerator.listChunkScripts(&cg);
        return cg;
    }

    pub fn deinit(self: *ChunkGenerator) void {
        self.scriptOptions.deinit();
    }

    pub fn draw(self: *ChunkGenerator, window: *glfw.Window) !void {
        if (!self.appState.app.showChunkGeneratorUI) {
            return;
        }
        const xPos: f32 = 1200.0;
        const yPos: f32 = 50.0;
        zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
        zgui.setNextWindowSize(.{
            .w = 2600,
            .h = 2000,
        });
        zgui.setNextItemWidth(-1);
        if (zgui.begin("Chunk Generator", .{
            .flags = .{
                .no_title_bar = false,
                .no_resize = false,
                .no_scrollbar = false,
                .no_collapse = false,
            },
        })) {
            try self.drawInput();
            zgui.sameLine(.{});
            try self.drawControls();
            try self.bm.draw(window);
        }
        zgui.end();
    }

    fn drawControls(self: *ChunkGenerator) !void {
        if (zgui.beginChild(
            "Create World",
            .{
                .w = 700,
                .h = 1950,
                .border = false,
            },
        )) {
            zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
            if (zgui.button("Generate chunk", .{
                .w = 500,
                .h = 75,
            })) {
                try self.evalChunkFunc();
            }
            if (zgui.button("Toggle wireframe", .{
                .w = 500,
                .h = 75,
            })) {
                self.toggleWireframe();
            }
            zgui.text("Chunk xyz:", .{});
            zgui.sameLine(.{});
            zgui.pushItemWidth(75);
            _ = zgui.inputTextWithHint("##chunkXPos", .{
                .buf = self.chunkXBuf[0..],
                .hint = "x",
            });
            zgui.sameLine(.{});
            _ = zgui.inputTextWithHint("##chunkYPos", .{
                .buf = self.chunkYBuf[0..],
                .hint = "y",
            });
            zgui.sameLine(.{});
            _ = zgui.inputTextWithHint("##chunkZPos", .{
                .buf = self.chunkZBuf[0..],
                .hint = "z",
            });
            zgui.popItemWidth();
            if (zgui.button("Generate to world", .{
                .w = 500,
                .h = 75,
            })) {
                try self.evalWorldChunkFunc();
            }
            if (zgui.colorEdit3("##Script color", .{
                .col = &self.scriptColor,
                .flags = .{
                    .picker_hue_bar = true,
                },
            })) {}
            zgui.pushFont(self.codeFont);
            zgui.pushItemWidth(500);
            _ = zgui.inputTextWithHint("##script name", .{
                .buf = self.nameBuf[0..],
                .hint = "chunk_script",
            });
            zgui.popItemWidth();
            zgui.popFont();
            if (zgui.button("Create script", .{
                .w = 500,
                .h = 75,
            })) {
                try self.saveChunkScriptFunc();
            }
            if (zgui.button("Update script", .{
                .w = 500,
                .h = 75,
            })) {
                try self.updateChunkScriptFunc();
            }
            if (zgui.button("Delete script", .{
                .w = 500,
                .h = 75,
            })) {
                try self.deleteChunkScriptFunc();
            }
            if (zgui.button("Refresh list", .{
                .w = 500,
                .h = 100,
            })) {
                try self.listChunkScripts();
            }
            zgui.popStyleVar(.{ .count = 1 });
            if (menus.scriptOptionsListBox(self.scriptOptions, .{})) |scriptOptionId| {
                try self.loadChunkScriptFunc(scriptOptionId);
            }
        }
        zgui.endChild();
    }

    fn drawInput(self: *ChunkGenerator) !void {
        if (zgui.beginChild(
            "script_input",
            .{
                .w = 1800,
                .h = 1950,
                .border = true,
            },
        )) {
            zgui.pushFont(self.codeFont);
            _ = zgui.inputTextMultiline(" ", .{
                .buf = self.buf[0..],
                .w = 1784,
                .h = 1900,
            });
            zgui.popFont();
        }
        zgui.endChild();
    }

    fn toggleWireframe(self: *ChunkGenerator) void {
        self.appState.demoScreen.toggleWireframe();
        self.appState.worldScreen.toggleWireframe();
    }

    fn evalChunkFunc(self: *ChunkGenerator) !void {
        try self.appState.demoScreen.clearChunks();
        const cData = self.script.evalChunkFunc(self.buf) catch |err| {
            std.debug.print("Error evaluating chunk function: {}\n", .{err});
            return;
        };
        try self.appState.demoScreen.addChunk(cData, state.position.Position{ .x = 0, .y = 0, .z = 0 });
        try self.appState.demoScreen.writeChunks();
    }

    fn floatFromChunkBuf(buf: []u8) f32 {
        const r = [_]u8{0};
        const b = std.mem.trim(u8, buf, &r);
        return std.fmt.parseFloat(f32, b) catch |err| {
            std.debug.print("Error parsing chunk position: {}\n", .{err});
            return 0.0;
        };
    }

    fn evalWorldChunkFunc(self: *ChunkGenerator) !void {
        try self.appState.worldScreen.clearChunks();
        const cData = try self.script.evalChunkFunc(self.buf);
        const x = floatFromChunkBuf(&self.chunkXBuf);
        const y = floatFromChunkBuf(&self.chunkYBuf);
        const z = floatFromChunkBuf(&self.chunkZBuf);
        std.debug.print("Writing chunk to world at position: {}, {}, {}\n", .{ x, y, z });
        try self.appState.worldScreen.addChunk(cData, state.position.Position{ .x = x, .y = y, .z = z });
        try self.appState.worldScreen.writeChunks();
    }

    fn listChunkScripts(self: *ChunkGenerator) !void {
        try self.appState.db.listChunkScripts(&self.scriptOptions);
    }

    fn loadChunkScriptFunc(self: *ChunkGenerator, scriptId: i32) !void {
        var scriptData: data.chunkScript = undefined;
        self.appState.db.loadChunkScript(scriptId, &scriptData) catch |err| {
            if (err != data.DataErr.NotFound) {
                return err;
            }
            return;
        };
        var nameBuf = [_]u8{0} ** script.maxLuaScriptNameSize;
        for (scriptData.name, 0..) |c, i| {
            if (i >= script.maxLuaScriptNameSize) {
                break;
            }
            nameBuf[i] = c;
        }
        self.buf = script.Script.dataScriptToScript(scriptData.script);
        self.nameBuf = nameBuf;
        self.scriptColor = scriptData.color;
        try self.evalChunkFunc();
        self.loadedScriptId = scriptId;
    }

    fn saveChunkScriptFunc(self: *ChunkGenerator) !void {
        const n = std.mem.indexOf(u8, &self.nameBuf, &([_]u8{0}));
        if (n) |i| {
            if (i < 3) {
                std.log.err("Script name is too short", .{});
                return;
            }
        }
        try self.appState.db.saveChunkScript(&self.nameBuf, &self.buf, self.scriptColor);
        try self.listChunkScripts();
    }

    fn updateChunkScriptFunc(self: *ChunkGenerator) !void {
        const n = std.mem.indexOf(u8, &self.nameBuf, &([_]u8{0}));
        if (n) |i| {
            if (i < 3) {
                std.log.err("Script name is too short", .{});
                return;
            }
        }
        try self.appState.db.updateChunkScript(self.loadedScriptId, &self.nameBuf, &self.buf, self.scriptColor);
        try self.listChunkScripts();
        try self.loadChunkScriptFunc(self.loadedScriptId);
    }

    fn deleteChunkScriptFunc(self: *ChunkGenerator) !void {
        try self.appState.db.deleteChunkScript(self.loadedScriptId);
        try self.listChunkScripts();
        self.loadedScriptId = 0;
    }
};
