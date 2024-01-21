const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const config = @import("../config.zig");
const position = @import("../position.zig");
const shape = @import("../shape/shape.zig");
const state = @import("../state.zig");
const chunk = @import("../chunk.zig");
const data = @import("../data/data.zig");
const script = @import("../script/script.zig");
const builder_menu = @import("builder_menu.zig");

const maxWorldSizeName = 20;

pub const ChunkGenerator = struct {
    script: script.Script,
    appState: *state.State,
    alloc: std.mem.Allocator,
    buf: [script.maxLuaScriptSize]u8,
    nameBuf: [script.maxLuaScriptNameSize]u8,
    codeFont: zgui.Font,
    scriptOptions: std.ArrayList(data.chunkScriptOption),
    loadedScriptId: i32 = 0,
    scriptColor: [3]f32,
    bm: builder_menu.BuilderMenu,

    pub fn init(
        appState: *state.State,
        codeFont: zgui.Font,
        sc: script.Script,
        bm: builder_menu.BuilderMenu,
        alloc: std.mem.Allocator,
    ) !ChunkGenerator {
        var buf = [_]u8{0} ** script.maxLuaScriptSize;
        const nameBuf = [_]u8{0} ** script.maxLuaScriptNameSize;
        const defaultLuaScript = @embedFile("../script/lua/chunk_gen_surface.lua");
        for (defaultLuaScript, 0..) |c, i| {
            buf[i] = c;
        }
        var cg = ChunkGenerator{
            .script = sc,
            .appState = appState,
            .alloc = alloc,
            .buf = buf,
            .nameBuf = nameBuf,
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
                .w = 500,
                .h = 1950,
                .border = false,
            },
        )) {
            zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
            if (zgui.button("Random chunk", .{
                .w = 500,
                .h = 75,
            })) {
                try self.generateRandomChunk();
            }
            if (zgui.button("Generate chunk", .{
                .w = 500,
                .h = 75,
            })) {
                try self.evalChunkFunc();
            }
            if (zgui.button("Toggle meshing", .{
                .w = 500,
                .h = 75,
            })) {
                try self.toggleMeshChunks();
            }
            if (zgui.button("Toggle wireframe", .{
                .w = 500,
                .h = 75,
            })) {
                self.toggleWireframe();
            }
            if (zgui.button("Generate to world", .{
                .w = 500,
                .h = 75,
            })) {
                try self.evalWorldChunkFunc();
            }
            if (zgui.colorEdit3("Script color", .{
                .col = &self.scriptColor,
                .flags = .{
                    .picker_hue_bar = true,
                },
            })) {}
            zgui.pushFont(self.codeFont);
            zgui.pushItemWidth(500);
            _ = zgui.inputTextWithHint("Script name", .{
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
            _ = zgui.beginListBox("##listbox", .{
                .w = 800,
                .h = 1100,
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
                    try self.loadChunkScriptFunc(scriptOption.id);
                }
            }
            zgui.endListBox();
            zgui.popStyleVar(.{ .count = 1 });
        }
        zgui.endChild();
    }

    fn drawInput(self: *ChunkGenerator) !void {
        if (zgui.beginChild(
            "script_input",
            .{
                .w = 2000,
                .h = 1950,
                .border = true,
            },
        )) {
            zgui.pushFont(self.codeFont);
            _ = zgui.inputTextMultiline(" ", .{
                .buf = self.buf[0..],
                .w = 1984,
                .h = 1900,
            });
            zgui.popFont();
        }
        zgui.endChild();
    }

    fn toggleWireframe(self: *ChunkGenerator) void {
        self.appState.demoView.toggleWireframe();
        self.appState.worldView.toggleWireframe();
    }

    fn toggleMeshChunks(self: *ChunkGenerator) !void {
        try self.appState.demoView.toggleMeshChunks();
    }

    fn generateRandomChunk(self: *ChunkGenerator) !void {
        try self.appState.demoView.clearChunks();
        const cData = self.appState.demoView.randomChunk(9001);
        try self.appState.demoView.addChunk(cData, position.Position{ .x = 0, .y = 0, .z = 0 });
        try self.appState.demoView.writeChunks();
    }

    fn evalChunkFunc(self: *ChunkGenerator) !void {
        try self.appState.demoView.clearChunks();
        const cData = self.script.evalChunkFunc(self.buf) catch |err| {
            std.debug.print("Error evaluating chunk function: {}\n", .{err});
            return;
        };
        try self.appState.demoView.addChunk(cData, position.Position{ .x = 0, .y = 0, .z = 0 });
        try self.appState.demoView.writeChunks();
    }

    fn evalWorldChunkFunc(self: *ChunkGenerator) !void {
        try self.appState.worldView.clearChunks();
        const cData = try self.script.evalChunkFunc(self.buf);
        try self.appState.worldView.addChunk(cData, position.Position{ .x = 0, .y = 0, .z = 0 });
        try self.appState.worldView.writeChunks();
        try self.appState.setGameView();
    }

    fn listChunkScripts(self: *ChunkGenerator) !void {
        try self.appState.db.listChunkScripts(&self.scriptOptions);
    }

    fn loadChunkScriptFunc(self: *ChunkGenerator, scriptId: i32) !void {
        var scriptData: data.chunkScript = undefined;
        try self.appState.db.loadChunkScript(scriptId, &scriptData);
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
