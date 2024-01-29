const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const config = @import("../config.zig");
const shape = @import("../shape/shape.zig");
const state = @import("../state.zig");
const position = @import("../position.zig");
const data = @import("../data/data.zig");
const script = @import("../script/script.zig");
const menus = @import("menus.zig");

const maxWorldSizeName = 20;

const emptyVoxels: [data.chunkSize]i32 = [_]i32{0} ** data.chunkSize;

const yOptions = enum {
    below,
    above,
};

const chunkConfig = struct {
    id: i32 = 0, // from sqlite
    scriptId: i32,
    chunkData: [data.chunkSize]i32 = emptyVoxels,
};

pub const WorldEditor = struct {
    script: script.Script,
    appState: *state.State,
    createNameBuf: [maxWorldSizeName]u8,
    codeFont: zgui.Font,
    worldOptions: std.ArrayList(data.worldOption),
    scriptOptions: std.ArrayList(data.chunkScriptOption),
    chunkTableData: std.AutoHashMap(state.worldPosition, chunkConfig),
    loadedWorldId: i32 = 0,
    chunkY: i32 = 0,
    currentChunk: position.Position = position.Position{ .x = 0, .y = 0, .z = 0 },
    bm: menus.BuilderMenu,
    alloc: std.mem.Allocator,

    pub fn init(
        appState: *state.State,
        codeFont: zgui.Font,
        sc: script.Script,
        bm: menus.BuilderMenu,
        alloc: std.mem.Allocator,
    ) !WorldEditor {
        const createNameBuf = [_]u8{0} ** maxWorldSizeName;
        var we = WorldEditor{
            .script = sc,
            .appState = appState,
            .createNameBuf = createNameBuf,
            .codeFont = codeFont,
            .worldOptions = std.ArrayList(data.worldOption).init(alloc),
            .scriptOptions = std.ArrayList(data.chunkScriptOption).init(alloc),
            .chunkTableData = std.AutoHashMap(state.worldPosition, chunkConfig).init(alloc),
            .bm = bm,
            .alloc = alloc,
        };
        try WorldEditor.listWorlds(&we);
        try WorldEditor.loadWorld(&we, 1);
        try WorldEditor.loadChunkDatas(&we);
        try WorldEditor.listChunkScripts(&we);
        return we;
    }

    pub fn deinit(self: *WorldEditor) void {
        self.worldOptions.deinit();
        self.scriptOptions.deinit();
        self.chunkTableData.deinit();
    }

    fn listChunkScripts(self: *WorldEditor) !void {
        try self.appState.db.listChunkScripts(&self.scriptOptions);
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
        self.loadedWorldId = worldId;
        try self.loadChunkDatas();
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
                if (zgui.button("Save chunks", .{
                    .w = 500,
                    .h = 100,
                })) {
                    try self.saveChunkDatas();
                }

                if (zgui.button("Generate chunks", .{
                    .w = 500,
                    .h = 100,
                })) {
                    try self.evalChunksFunc();
                }

                if (zgui.button("Load world", .{
                    .w = 500,
                    .h = 100,
                })) {
                    try self.loadChunksInWorld();
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
            try self.drawTopDownChunkConfgOptions();
            try self.drawTopDownChunkConfig();
        }
        zgui.endChild();
    }

    fn drawTopDownChunkConfgOptions(self: *WorldEditor) !void {
        var enum_val: yOptions = .below;
        if (self.chunkY == 1) {
            enum_val = .above;
        }
        zgui.setNextItemWidth(500);
        if (zgui.comboFromEnum("select y", &enum_val)) {
            if (self.chunkY == 1 and enum_val == .below) {
                self.chunkY = 0;
                try self.loadChunkDatas();
            } else if (self.chunkY == 0 and enum_val == .above) {
                self.chunkY = 1;
                try self.loadChunkDatas();
            }
        }
    }

    fn drawChunkConfigPopup(self: *WorldEditor) !void {
        if (zgui.beginPopup("ScriptsPicker", .{})) {
            zgui.text("Select a script for this chunk", .{});
            if (zgui.smallButton("x")) {
                zgui.closeCurrentPopup();
            }
            try self.listChunkScripts();
            if (menus.scriptOptionsListBox(self.scriptOptions, .{ .w = 700 })) |scriptOptionId| {
                std.debug.print("selected {d} for chunk at ({d},{d},{d})\n", .{
                    scriptOptionId,
                    self.currentChunk.x,
                    self.currentChunk.y,
                    self.currentChunk.z,
                });
                const wp = state.worldPosition.initFromPosition(self.currentChunk);

                var id: i32 = 0;
                if (self.chunkTableData.get(wp)) |ch_cfg| {
                    id = ch_cfg.id;
                }
                const ch_cfg: chunkConfig = .{
                    .id = id,
                    .scriptId = scriptOptionId,
                };
                try self.chunkTableData.put(wp, ch_cfg);
            }
            zgui.endPopup();
        }
    }

    const chunkConfigInfo = struct {
        col: u32,
        name: [:0]u8,
    };

    fn drawChunkConfigColumn(self: *WorldEditor, p: position.Position, w: f32, h: f32) !void {
        const wp = state.worldPosition.initFromPosition(p);
        var info: ?chunkConfigInfo = null;
        if (self.chunkTableData.get(wp)) |ch_cfg| {
            for (self.scriptOptions.items) |so| {
                if (so.id == ch_cfg.scriptId) {
                    var sn = so.name;
                    var st: usize = 0;
                    for (0..so.name.len) |i| {
                        if (so.name[i] == 0) {
                            st = i;
                            break;
                        }
                    }
                    if (st == 0) {
                        break;
                    }
                    info = .{
                        .col = zgui.colorConvertFloat3ToU32(so.color),
                        .name = sn[0..st :0],
                    };
                }
            }
        }
        if (zgui.tableNextColumn()) {
            const cFlags = zgui.tableGetColumnFlags(.{});
            if (cFlags.is_hovered) {
                // do something?
            }
            var buffer: [10]u8 = undefined;
            const colHeader: [:0]const u8 = try std.fmt.bufPrintZ(&buffer, "{d}_{d}", .{ p.x, p.z });

            if (zgui.invisibleButton(colHeader, .{
                .w = w,
                .h = h,
            })) {
                self.currentChunk = p;
                zgui.openPopup("ScriptsPicker", .{});
            }

            var dl = zgui.getWindowDrawList();
            var pmin = zgui.getCursorScreenPos();
            var pmax = [2]f32{ pmin[0] + w, pmin[1] };
            pmin[1] = pmin[1] - h;
            var col = zgui.colorConvertFloat4ToU32(.{ 0.25, 0.25, 0.25, 1.0 });
            const hovering = zgui.isItemHovered(.{});
            if (hovering) {
                col = zgui.colorConvertFloat4ToU32(.{ 0.5, 0.5, 0.5, 1.0 });
            }
            dl.addRectFilled(.{ .pmin = pmin, .pmax = pmax, .col = col });
            if (info) |ci| {
                pmin = zgui.getCursorScreenPos();
                const yStart = pmin[1] - h;
                pmin[1] = yStart;
                pmax = [2]f32{ pmin[0] + 50, yStart + 50 };
                dl.addRectFilled(.{ .pmin = pmin, .pmax = pmax, .col = ci.col });
                if (hovering and zgui.beginTooltip()) {
                    zgui.text("{s}", .{ci.name[0.. :0]});
                    zgui.endTooltip();
                }
            }
        }
    }

    fn drawTopDownChunkConfig(self: *WorldEditor) !void {
        const colWidth: f32 = 1500 / config.worldChunkDims;
        if (zgui.beginTable("chunks", .{
            .outer_size = .{ 1500, 1500 },
            .column = config.worldChunkDims + 1,
        })) {
            zgui.tableSetupColumn("z, x", .{});
            for (0..config.worldChunkDims) |i| {
                const x: i32 = @as(i32, @intCast(i)) - @as(i32, @intCast(config.worldChunkDims / 2));
                var buffer: [10]u8 = undefined;
                const colHeader: [:0]const u8 = try std.fmt.bufPrintZ(&buffer, "{d}", .{x});
                zgui.tableSetupColumn(colHeader, .{});
            }
            zgui.tableHeadersRow();
            try self.drawChunkConfigPopup();
            for (0..config.worldChunkDims) |i| {
                const z: i32 = @as(i32, @intCast(i)) - @as(i32, @intCast(config.worldChunkDims / 2));
                zgui.tableNextRow(.{
                    .min_row_height = colWidth,
                });
                if (zgui.tableNextColumn()) {
                    zgui.text("{d}", .{z});
                }
                for (0..config.worldChunkDims) |ii| {
                    const x: i32 = @as(i32, @intCast(ii)) - @as(i32, @intCast(config.worldChunkDims / 2));
                    const p = position.Position{
                        .x = @as(gl.Float, @floatFromInt(x)),
                        .y = @as(gl.Float, @floatFromInt(self.chunkY)),
                        .z = @as(gl.Float, @floatFromInt(z)),
                    };
                    try self.drawChunkConfigColumn(p, colWidth, colWidth);
                }
            }
            zgui.endTable();
        }
    }

    fn loadChunksInWorld(self: *WorldEditor) !void {
        try self.appState.worldView.clearChunks();
        var instancedKeys = self.chunkTableData.keyIterator();
        while (instancedKeys.next()) |_k| {
            if (@TypeOf(_k) == *state.worldPosition) {
                const wp = _k.*;
                const ch_cfg = self.chunkTableData.get(wp).?;
                const p = wp.positionFromWorldPosition();
                try self.appState.worldView.addChunk(ch_cfg.chunkData, p);
            } else {
                @panic("unexpected key type in load chunks in world func");
            }
        }
        try self.appState.worldView.writeChunks();
    }

    fn evalChunksFunc(self: *WorldEditor) !void {
        var scriptCache = std.AutoHashMap(i32, [script.maxLuaScriptSize]u8).init(self.alloc);
        defer scriptCache.deinit();

        var instancedKeys = self.chunkTableData.keyIterator();
        while (instancedKeys.next()) |_k| {
            if (@TypeOf(_k) == *state.worldPosition) {
                const wp = _k.*;
                var ch_cfg = self.chunkTableData.get(wp).?;
                var ch_script: [script.maxLuaScriptSize]u8 = undefined;
                if (scriptCache.get(ch_cfg.scriptId)) |sc| {
                    ch_script = sc;
                } else {
                    var scriptData: data.chunkScript = undefined;
                    try self.appState.db.loadChunkScript(ch_cfg.scriptId, &scriptData);
                    ch_script = script.Script.dataScriptToScript(scriptData.script);
                    try scriptCache.put(ch_cfg.scriptId, ch_script);
                }
                const cData = self.script.evalChunkFunc(ch_script) catch |err| {
                    std.debug.print("Error evaluating chunk in eval chunks function: {}\n", .{err});
                    return;
                };
                ch_cfg.chunkData = cData;
                try self.chunkTableData.put(wp, ch_cfg);
                const p = wp.positionFromWorldPosition();
                try self.appState.worldView.addChunk(cData, p);
            } else {
                @panic("unexpected key type in eval chunks func");
            }
        }
    }

    fn saveChunkDatas(self: *WorldEditor) !void {
        for (0..config.worldChunkDims) |i| {
            const x: i32 = @as(i32, @intCast(i)) - @as(i32, @intCast(config.worldChunkDims / 2));
            inner: for (0..config.worldChunkDims) |ii| {
                const z: i32 = @as(i32, @intCast(ii)) - @as(i32, @intCast(config.worldChunkDims / 2));
                const y = self.chunkY;
                const p = position.Position{
                    .x = @as(f32, @floatFromInt(x)),
                    .y = @as(f32, @floatFromInt(y)),
                    .z = @as(f32, @floatFromInt(z)),
                };
                const wp = state.worldPosition.initFromPosition(p);
                if (self.chunkTableData.get(wp)) |ch_cfg| {
                    if (ch_cfg.id != 0) {
                        // update
                        try self.appState.db.updateChunkData(
                            ch_cfg.id,
                            ch_cfg.scriptId,
                            ch_cfg.chunkData,
                        );
                        continue :inner;
                    }
                    // insert
                    try self.appState.db.saveChunkData(
                        self.loadedWorldId,
                        x,
                        y,
                        z,
                        ch_cfg.scriptId,
                        ch_cfg.chunkData,
                    );
                    continue :inner;
                }
            }
        }
    }

    fn loadChunkDatas(self: *WorldEditor) !void {
        self.chunkTableData.clearAndFree();
        for (0..2) |_i| {
            const y: i32 = @as(i32, @intCast(_i));
            for (0..config.worldChunkDims) |i| {
                const x: i32 = @as(i32, @intCast(i)) - @as(i32, @intCast(config.worldChunkDims / 2));
                for (0..config.worldChunkDims) |ii| {
                    const z: i32 = @as(i32, @intCast(ii)) - @as(i32, @intCast(config.worldChunkDims / 2));
                    var chunkData = data.chunkData{};
                    self.appState.db.loadChunkData(self.loadedWorldId, x, y, z, &chunkData) catch |err| {
                        if (err == data.DataErr.NotFound) {
                            continue;
                        }
                        return err;
                    };
                    const p = position.Position{
                        .x = @as(gl.Float, @floatFromInt(x)),
                        .y = @as(gl.Float, @floatFromInt(y)),
                        .z = @as(gl.Float, @floatFromInt(z)),
                    };
                    const wp = state.worldPosition.initFromPosition(p);
                    const cfg = chunkConfig{
                        .id = chunkData.id,
                        .scriptId = chunkData.scriptId,
                        .chunkData = chunkData.voxels,
                    };
                    try self.chunkTableData.put(wp, cfg);
                }
            }
        }
    }
};
