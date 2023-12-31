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

const maxBlockSizeName = 20;

pub const BlockEditor = struct {
    appState: *state.State,
    createNameBuf: [maxBlockSizeName]u8,
    updateNameBuf: [maxBlockSizeName]u8,
    luaInstance: Lua,
    codeFont: zgui.Font,
    blockOptions: std.ArrayList(data.blockOption),
    loadedBlockId: u32 = 0,

    pub fn init(appState: *state.State, codeFont: zgui.Font, alloc: std.mem.Allocator) !BlockEditor {
        var lua: Lua = try Lua.init(alloc);
        lua.openLibs();
        const createNameBuf = [_]u8{0} ** maxBlockSizeName;
        const updateNameBuf = [_]u8{0} ** maxBlockSizeName;
        var tv = BlockEditor{
            .appState = appState,
            .createNameBuf = createNameBuf,
            .updateNameBuf = updateNameBuf,
            .luaInstance = lua,
            .codeFont = codeFont,
            .blockOptions = std.ArrayList(data.blockOption).init(alloc),
        };
        try BlockEditor.listBlocks(&tv);
        return tv;
    }

    pub fn deinit(self: *BlockEditor) void {
        self.luaInstance.deinit();
    }

    pub fn draw(self: *BlockEditor, window: *glfw.Window) !void {
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
        if (zgui.begin("Block Editor", .{
            .flags = .{
                .no_title_bar = false,
                .no_resize = true,
                .no_scrollbar = false,
                .no_collapse = true,
            },
        })) {
            try self.drawBlockOptions();
            if (self.loadedBlockId != 0) {
                zgui.sameLine(.{});
                try self.drawBlockConfig();
            }
        }
        zgui.end();
        zgui.backend.draw();
    }

    fn listBlocks(self: *BlockEditor) !void {
        try self.appState.db.listBlocks(&self.blockOptions);
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

    fn loadBlock(self: *BlockEditor, blockId: u32) !void {
        var blockData: data.block = undefined;
        try self.appState.db.loadBlock(blockId, &blockData);
        var nameBuf = [_]u8{0} ** maxBlockSizeName;
        for (blockData.name, 0..) |c, i| {
            if (i >= maxBlockSizeName) {
                break;
            }
            nameBuf[i] = c;
        }
        self.updateNameBuf = nameBuf;
        self.loadedBlockId = blockId;
    }

    fn updateBlock(self: *BlockEditor) !void {
        const n = std.mem.indexOf(u8, &self.updateNameBuf, &([_]u8{0}));
        if (n) |i| {
            if (i < 3) {
                std.log.err("Block name is too short", .{});
                return;
            }
        }
        const emtpyText = [_]gl.Uint{0} ** data.RGBAColorTextureSize;
        try self.appState.db.updateBlock(self.loadedBlockId, &self.updateNameBuf, emtpyText);
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
            const style = zgui.getStyle();
            var text_color = style.getColor(.text);
            text_color = .{ 0.0, 0.0, 0.0, 1.00 };
            style.setColor(.text, text_color);
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
                var buffer: [maxBlockSizeName + 10]u8 = undefined;
                const selectableName = try std.fmt.bufPrint(&buffer, "{d}: {s}", .{ blockOption.id, blockOption.name });
                var name: [maxBlockSizeName:0]u8 = undefined;
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
            const style = zgui.getStyle();
            var text_color = style.getColor(.text);
            text_color = .{ 0.0, 0.0, 0.0, 1.00 };
            style.setColor(.text, text_color);
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
