const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl").bindings;
const glfw = @import("zglfw");
const config = @import("../config.zig");
const shape = @import("../shape/shape.zig");
const state = @import("../state/state.zig");
const data = @import("../data/data.zig");
const script = @import("../script/script.zig");
const menus = @import("menus.zig");

pub const BlockEditor = struct {
    loadedBlockId: i32,
    loadedScriptId: i32,
    script: script.Script,
    appState: *state.State,
    createNameBuf: [data.maxBlockSizeName]u8,
    updateNameBuf: [data.maxBlockSizeName]u8,
    codeFont: zgui.Font,
    blockOptions: std.ArrayList(data.blockOption),
    scriptOptions: std.ArrayList(data.scriptOption),
    bm: menus.BuilderMenu,

    pub fn init(
        appState: *state.State,
        codeFont: zgui.Font,
        sc: script.Script,
        bm: menus.BuilderMenu,
        alloc: std.mem.Allocator,
    ) !BlockEditor {
        const createNameBuf = [_]u8{0} ** data.maxBlockSizeName;
        const updateNameBuf = [_]u8{0} ** data.maxBlockSizeName;
        var tv = BlockEditor{
            .loadedBlockId = 0,
            .loadedScriptId = 0,
            .script = sc,
            .appState = appState,
            .createNameBuf = createNameBuf,
            .updateNameBuf = updateNameBuf,
            .codeFont = codeFont,
            .blockOptions = std.ArrayList(data.blockOption).init(alloc),
            .scriptOptions = std.ArrayList(data.scriptOption).init(alloc),
            .bm = bm,
        };
        try BlockEditor.listBlocks(&tv);
        try BlockEditor.listTextureScripts(&tv);
        return tv;
    }

    pub fn deinit(self: *BlockEditor) void {
        self.scriptOptions.deinit();
        self.blockOptions.deinit();
    }

    pub fn draw(self: *BlockEditor, window: *glfw.Window) !void {
        const xPos: f32 = 700.0;
        const yPos: f32 = 50.0;
        zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
        zgui.setNextWindowSize(.{
            .w = 2850,
            .h = 2000,
        });
        zgui.setNextItemWidth(-1);
        if (zgui.begin("Block Editor", .{
            .flags = .{
                .no_title_bar = false,
                .no_resize = true,
                .no_scrollbar = false,
                .no_collapse = true,
            },
        })) {
            try self.bm.draw(window);
            try self.drawBlockOptions();
            if (self.loadedBlockId != 0) {
                zgui.sameLine(.{});
                try self.drawBlockConfig();
            }
        }
        zgui.end();
    }

    fn listBlocks(self: *BlockEditor) !void {
        try self.appState.db.listBlocks(&self.blockOptions);
    }

    fn listTextureScripts(self: *BlockEditor) !void {
        try self.appState.db.listTextureScripts(&self.scriptOptions);
    }

    fn saveBlock(self: *BlockEditor) !void {
        const n = std.mem.indexOf(u8, &self.createNameBuf, &([_]u8{0}));
        if (n) |i| {
            if (i < 3) {
                std.log.err("Block name is too short", .{});
                return;
            }
        }
        const emptyText = [_]gl.Uint{0} ** data.RGBAColorTextureSize;
        try self.appState.db.saveBlock(&self.createNameBuf, emptyText);
        try self.listBlocks();
    }

    fn loadBlock(self: *BlockEditor, blockId: i32) !void {
        var blockData: data.block = undefined;
        try self.appState.db.loadBlock(blockId, &blockData);
        var nameBuf = [_]u8{0} ** data.maxBlockSizeName;
        for (blockData.name, 0..) |c, i| {
            if (i >= data.maxBlockSizeName) {
                break;
            }
            nameBuf[i] = c;
        }
        self.updateNameBuf = nameBuf;
        self.loadedBlockId = blockId;
        self.appState.app.setTextureColor(blockData.texture);
    }

    fn evalTextureFunc(self: *BlockEditor, buf: [script.maxLuaScriptSize]u8) !void {
        const textureRGBAColor = try self.script.evalTextureFunc(buf);
        self.appState.app.setTextureColor(textureRGBAColor);
    }

    fn loadTextureScriptFunc(self: *BlockEditor, scriptId: i32) !void {
        var scriptData: data.script = undefined;
        try self.appState.db.loadTextureScript(scriptId, &scriptData);
        var buf = [_]u8{0} ** script.maxLuaScriptSize;
        for (scriptData.script, 0..) |c, i| {
            if (i >= script.maxLuaScriptSize) {
                break;
            }
            buf[i] = c;
        }
        try self.evalTextureFunc(buf);
        self.loadedScriptId = scriptId;
    }

    fn updateBlock(self: *BlockEditor) !void {
        const n = std.mem.indexOf(u8, &self.updateNameBuf, &([_]u8{0}));
        if (n) |i| {
            if (i < 3) {
                std.log.err("Block name is too short", .{});
                return;
            }
        }
        var textureColors = [_]gl.Uint{0} ** data.RGBAColorTextureSize;
        if (self.appState.app.demoTextureColors) |colors| {
            textureColors = colors;
        }
        try self.appState.db.updateBlock(self.loadedBlockId, &self.updateNameBuf, textureColors);
        try self.listBlocks();
        try self.loadBlock(self.loadedBlockId);
    }

    fn deleteBlock(self: *BlockEditor) !void {
        try self.appState.db.deleteBlock(self.loadedBlockId);
        try self.listBlocks();
        self.loadedBlockId = 0;
    }

    fn drawBlockOptions(self: *BlockEditor) !void {
        if (zgui.beginChild(
            "Saved Blocks",
            .{
                .w = 850,
                .h = 1800,
                .border = true,
            },
        )) {
            try self.drawBlockList();
            try self.drawCreateForm();
        }
        zgui.endChild();
    }

    fn drawBlockConfig(self: *BlockEditor) !void {
        if (zgui.beginChild(
            "Configure Block",
            .{
                .w = 1800,
                .h = 1800,
                .border = true,
            },
        )) {
            zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
            if (zgui.button("Update block", .{
                .w = 500,
                .h = 100,
            })) {
                try self.updateBlock();
            }
            zgui.popStyleVar(.{ .count = 1 });
            zgui.pushFont(self.codeFont);
            zgui.pushItemWidth(400);
            _ = zgui.inputTextWithHint("Name", .{
                .buf = self.updateNameBuf[0..],
                .hint = "block name",
            });
            if (zgui.button("Delete block", .{
                .w = 450,
                .h = 100,
            })) {
                try self.deleteBlock();
            }
            zgui.popItemWidth();
            zgui.popFont();
            zgui.text("Select a texture", .{});
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
        }
        zgui.endChild();
    }

    fn drawBlockList(self: *BlockEditor) !void {
        if (zgui.beginChild(
            "Blocks",
            .{
                .w = 850,
                .h = 1450,
                .border = false,
            },
        )) {
            if (zgui.button("Refresh list", .{
                .w = 450,
                .h = 100,
            })) {
                try self.listBlocks();
            }
            _ = zgui.beginListBox("##listbox", .{
                .w = 800,
                .h = 1400,
            });
            for (self.blockOptions.items) |blockOption| {
                var buffer: [data.maxBlockSizeName + 10]u8 = undefined;
                const selectableName = try std.fmt.bufPrint(&buffer, "{d}: {s}", .{ blockOption.id, blockOption.name });
                var name: [data.maxBlockSizeName:0]u8 = undefined;
                for (name, 0..) |_, i| {
                    if (selectableName.len <= i) {
                        name[i] = 0;
                        break;
                    }
                    name[i] = selectableName[i];
                }
                if (zgui.selectable(&name, .{})) {
                    try self.loadBlock(blockOption.id);
                }
            }
            zgui.endListBox();
            if (self.loadedBlockId != 0) {
                if (zgui.button("Update block", .{
                    .w = 450,
                    .h = 100,
                })) {
                    try self.updateBlock();
                }
                if (zgui.button("Delete block", .{
                    .w = 450,
                    .h = 100,
                })) {
                    try self.deleteBlock();
                }
            }
        }
        zgui.endChild();
    }

    fn drawCreateForm(self: *BlockEditor) !void {
        if (zgui.beginChild(
            "Create Block",
            .{
                .w = 850,
                .h = 1800,
                .border = false,
            },
        )) {
            zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
            if (zgui.button("Create block", .{
                .w = 500,
                .h = 100,
            })) {
                try self.saveBlock();
            }
            zgui.popStyleVar(.{ .count = 1 });
            zgui.pushFont(self.codeFont);
            zgui.pushItemWidth(400);
            _ = zgui.inputTextWithHint("Name", .{
                .buf = self.createNameBuf[0..],
                .hint = "block name",
            });
            zgui.popItemWidth();
            zgui.popFont();
        }
        zgui.endChild();
    }
};
