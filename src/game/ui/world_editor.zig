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
    updateNameBuf: [maxWorldSizeName]u8,
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
        const updateNameBuf = [_]u8{0} ** maxWorldSizeName;
        var tv = WorldEditor{
            .appState = appState,
            .createNameBuf = createNameBuf,
            .updateNameBuf = updateNameBuf,
            .codeFont = codeFont,
            .worldOptions = std.ArrayList(data.worldOption).init(alloc),
            .bm = bm,
        };
        try WorldEditor.listWorlds(&tv);
        return tv;
    }

    pub fn deinit(self: *WorldEditor) void {
        self.worldOptions.deinit();
    }

    pub fn draw(self: *WorldEditor, window: *glfw.Window) !void {
        const xPos: f32 = 700.0;
        const yPos: f32 = 50.0;
        zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
        zgui.setNextWindowSize(.{
            .w = 2850,
            .h = 2000,
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
        self.updateNameBuf = nameBuf;
        self.loadedWorldId = @as(u32, @intCast(worldId));
    }

    fn updateWorld(self: *WorldEditor) !void {
        const n = std.mem.indexOf(u8, &self.updateNameBuf, &([_]u8{0}));
        if (n) |i| {
            if (i < 3) {
                std.log.err("World name is too short", .{});
                return;
            }
        }
        const id = @as(i32, @intCast(self.loadedWorldId));
        try self.appState.db.updateWorld(id, &self.updateNameBuf);
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
                .w = 850,
                .h = 1800,
                .border = true,
            },
        )) {
            try self.drawWorldList();
            try self.drawCreateForm();
        }
        zgui.endChild();
    }

    fn drawWorldConfig(self: *WorldEditor) !void {
        if (zgui.beginChild(
            "Configure World",
            .{
                .w = 1800,
                .h = 1800,
                .border = true,
            },
        )) {
            zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
            if (zgui.button("Update world", .{
                .w = 500,
                .h = 100,
            })) {
                try self.updateWorld();
            }
            zgui.popStyleVar(.{ .count = 1 });
            zgui.pushFont(self.codeFont);
            zgui.pushItemWidth(400);
            _ = zgui.inputTextWithHint("Name", .{
                .buf = self.updateNameBuf[0..],
                .hint = "world name",
            });
            if (zgui.button("Delete world", .{
                .w = 450,
                .h = 100,
            })) {
                try self.deleteWorld();
            }
            zgui.popItemWidth();
            zgui.popFont();
        }
        zgui.endChild();
    }

    fn drawWorldList(self: *WorldEditor) !void {
        if (zgui.beginChild(
            "Worlds",
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
                try self.listWorlds();
            }
            _ = zgui.beginListBox("##listbox", .{
                .w = 800,
                .h = 1400,
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

    fn drawCreateForm(self: *WorldEditor) !void {
        if (zgui.beginChild(
            "Create World",
            .{
                .w = 850,
                .h = 1800,
                .border = false,
            },
        )) {
            zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
            if (zgui.button("Create world", .{
                .w = 500,
                .h = 100,
            })) {
                try self.saveWorld();
            }
            zgui.popStyleVar(.{ .count = 1 });
            zgui.pushFont(self.codeFont);
            zgui.pushItemWidth(400);
            _ = zgui.inputTextWithHint("Name", .{
                .buf = self.createNameBuf[0..],
                .hint = "world name",
            });
            zgui.popItemWidth();
            zgui.popFont();
        }
        zgui.endChild();
    }
};
