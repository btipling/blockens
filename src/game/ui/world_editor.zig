const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const config = @import("../config.zig");
const shape = @import("../shape/shape.zig");
const state = @import("../state.zig");
const data = @import("../data/data.zig");
const builder_menu = @import("builder_menu.zig");

const maxWorldSizeName = 20;

pub const WorldEditor = struct {
    appState: *state.State,
    createNameBuf: [maxWorldSizeName]u8,
    codeFont: zgui.Font,
    worldOptions: std.ArrayList(data.worldOption),
    loadedWorldId: u32 = 0,
    bm: builder_menu.BuilderMenu,

    pub fn init(
        appState: *state.State,
        codeFont: zgui.Font,
        bm: builder_menu.BuilderMenu,
        alloc: std.mem.Allocator,
    ) !WorldEditor {
        const createNameBuf = [_]u8{0} ** maxWorldSizeName;
        var tv = WorldEditor{
            .appState = appState,
            .createNameBuf = createNameBuf,
            .codeFont = codeFont,
            .worldOptions = std.ArrayList(data.worldOption).init(alloc),
            .bm = bm,
        };
        try WorldEditor.listWorlds(&tv);
        try WorldEditor.loadWorld(&tv, 1);
        return tv;
    }

    pub fn deinit(self: *WorldEditor) void {
        self.worldOptions.deinit();
    }

    pub fn draw(self: *WorldEditor, window: *glfw.Window) !void {
        const xPos: f32 = 50.0;
        const yPos: f32 = 50.0;
        zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
        zgui.setNextWindowSize(.{
            .w = 3750,
            .h = 2200,
        });
        zgui.setNextItemWidth(-1);
        if (zgui.begin("World Editor", .{
            .flags = .{
                .no_title_bar = false,
                .no_resize = true,
                .no_scrollbar = false,
                .no_collapse = true,
            },
        })) {
            try self.bm.draw(window);
            try self.drawWorldOptions();
            if (self.loadedWorldId != 0) {
                zgui.sameLine(.{});
                try self.drawWorldConfig();
            }
        }
        zgui.end();
    }

    fn listWorlds(self: *WorldEditor) !void {
        try self.appState.db.listWorlds(&self.worldOptions);
    }

    fn saveWorld(self: *WorldEditor) !void {
        const n = std.mem.indexOf(u8, &self.createNameBuf, &([_]u8{0}));
        if (n) |i| {
            if (i < 3) {
                std.log.err("World name is too short", .{});
                return;
            }
        }
        try self.appState.db.saveWorld(&self.createNameBuf);
        try self.listWorlds();
    }

    fn loadWorld(self: *WorldEditor, worldId: i32) !void {
        var worldData: data.world = undefined;
        try self.appState.db.loadWorld(worldId, &worldData);
        var nameBuf = [_]u8{0} ** maxWorldSizeName;
        for (worldData.name, 0..) |c, i| {
            if (i >= maxWorldSizeName) {
                break;
            }
            nameBuf[i] = c;
        }
        self.createNameBuf = nameBuf;
        self.loadedWorldId = @as(u32, @intCast(worldId));
    }

    fn updateWorld(self: *WorldEditor) !void {
        const n = std.mem.indexOf(u8, &self.createNameBuf, &([_]u8{0}));
        if (n) |i| {
            if (i < 3) {
                std.log.err("World name is too short", .{});
                return;
            }
        }
        const id = @as(i32, @intCast(self.loadedWorldId));
        try self.appState.db.updateWorld(id, &self.createNameBuf);
        try self.listWorlds();
        try self.loadWorld(id);
    }

    fn deleteWorld(self: *WorldEditor) !void {
        const id = @as(i32, @intCast(self.loadedWorldId));
        try self.appState.db.deleteWorld(id);
        try self.listWorlds();
        self.loadedWorldId = 0;
    }

    fn drawWorldOptions(self: *WorldEditor) !void {
        if (zgui.beginChild(
            "Saved Worlds",
            .{
                .w = 510,
                .h = 2100,
                .border = true,
            },
        )) {
            _ = zgui.beginListBox("##listbox", .{
                .w = 500,
                .h = 1290,
            });
            for (self.worldOptions.items) |worldOption| {
                var buffer: [maxWorldSizeName + 10]u8 = undefined;
                const selectableName = try std.fmt.bufPrint(&buffer, "{d}: {s}", .{ worldOption.id, worldOption.name });
                var name: [maxWorldSizeName:0]u8 = undefined;
                for (name, 0..) |_, i| {
                    if (selectableName.len <= i) {
                        name[i] = 0;
                        break;
                    }
                    name[i] = selectableName[i];
                }
                if (zgui.selectable(&name, .{})) {
                    try self.loadWorld(worldOption.id);
                }
            }
            zgui.endListBox();
            zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
            if (zgui.button("Refresh list", .{
                .w = 500,
                .h = 100,
            })) {
                try self.listWorlds();
            }
            if (zgui.button("Create world", .{
                .w = 500,
                .h = 100,
            })) {
                try self.saveWorld();
            }
            zgui.pushFont(self.codeFont);
            zgui.pushItemWidth(500);
            _ = zgui.inputTextWithHint("##Name", .{
                .buf = self.createNameBuf[0..],
                .hint = "world name",
            });
            zgui.popItemWidth();
            zgui.popFont();
            if (self.loadedWorldId != 0) {
                if (zgui.button("Update world", .{
                    .w = 500,
                    .h = 100,
                })) {
                    try self.updateWorld();
                }
                if (zgui.button("Delete world", .{
                    .w = 500,
                    .h = 100,
                })) {
                    try self.deleteWorld();
                }
            }
            zgui.popStyleVar(.{ .count = 1 });
        }
        zgui.endChild();
    }

    fn drawWorldConfig(self: *WorldEditor) !void {
        if (zgui.beginChild(
            "Configure World",
            .{
                .w = 3250,
                .h = 2100,
                .border = true,
            },
        )) {
            try self.drawTopDownChunkConfig();
        }
        zgui.endChild();
    }

    fn drawTopDownChunkConfig(self: *WorldEditor) !void {
        _ = self;
        const colWidth: f32 = 1500 / config.worldChunkDims;
        if (zgui.beginTable("chunks", .{
            .outer_size = .{ 1500, 1500 },
            .column = config.worldChunkDims + 1,
        })) {
            zgui.tableSetupColumn("x,z", .{});
            for (0..config.worldChunkDims) |i| {
                var buffer: [10]u8 = undefined;
                const colHeader: [:0]const u8 = try std.fmt.bufPrintZ(&buffer, "{d}", .{i});
                zgui.tableSetupColumn(colHeader, .{});
            }
            zgui.tableHeadersRow();
            for (0..config.worldChunkDims) |i| {
                zgui.tableNextRow(.{
                    .min_row_height = colWidth,
                });
                if (zgui.tableNextColumn()) {
                    zgui.text("{d}", .{i});
                }
                for (0..config.worldChunkDims) |ii| {
                    _ = ii;
                    if (zgui.tableNextColumn()) {
                        zgui.text("tb", .{});
                    }
                }
            }
            zgui.endTable();
        }
    }
};
