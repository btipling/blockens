const yOptions = enum {
    below,
    above,
};

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UIWorldEditorSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.WorldEditor) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = game.state.ui.imguiX(25);
            const yPos: f32 = game.state.ui.imguiY(25);
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = game.state.ui.imguiWidth(1800),
                .h = game.state.ui.imguiHeight(1000),
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
                drawWorldOptions() catch unreachable;
                if (game.state.ui.world_loaded_id != 0) {
                    zgui.sameLine(.{});
                    drawWorldConfig() catch unreachable;
                }
            }
            zgui.end();
        }
    }
}

fn listChunkScripts() !void {
    try game.state.db.listChunkScripts(&game.state.ui.chunk_script_options);
}

fn listWorlds() !void {
    try game.state.db.listWorlds(&game.state.ui.world_options);
}

fn saveWorld() !void {
    const n = std.mem.indexOf(u8, &game.state.ui.world_name_buf, &([_]u8{0}));
    if (n) |i| {
        if (i < 3) {
            std.log.err("World name is too short", .{});
            return;
        }
    }
    try game.state.db.saveWorld(&game.state.ui.world_name_buf);
    try listWorlds();
}

fn loadWorld(worldId: i32) !void {
    var worldData: data.world = undefined;
    try game.state.db.loadWorld(worldId, &worldData);
    var nameBuf = [_]u8{0} ** ui.max_world_name;
    for (worldData.name, 0..) |c, i| {
        if (i >= ui.max_world_name) {
            break;
        }
        nameBuf[i] = c;
    }
    game.state.ui.world_name_buf = nameBuf;
    game.state.ui.world_loaded_id = worldId;
    try helpers.loadChunkDatas();
}

fn updateWorld() !void {
    const n = std.mem.indexOf(u8, &game.state.ui.world_name_buf, &([_]u8{0}));
    if (n) |i| {
        if (i < 3) {
            std.log.err("World name is too short", .{});
            return;
        }
    }
    const id = @as(i32, @intCast(game.state.ui.world_loaded_id));
    try game.state.db.updateWorld(id, &game.state.ui.world_name_buf);
    try listWorlds();
    try loadWorld(id);
}

fn deleteWorld() !void {
    const id = @as(i32, @intCast(game.state.ui.world_loaded_id));
    try game.state.db.deleteWorld(id);
    try game.state.db.deletePlayerPosition(id);
    try game.state.db.deleteChunkData(id);
    try listWorlds();
    game.state.ui.world_loaded_id = 0;
}

fn drawWorldOptions() !void {
    if (zgui.beginChild(
        "Saved Worlds",
        .{
            .w = game.state.ui.imguiWidth(255),
            .h = game.state.ui.imguiHeight(900),
            .border = true,
        },
    )) {
        const btn_dms: [2]f32 = game.state.ui.imguiButtonDims();
        _ = zgui.beginListBox("##listbox", .{
            .w = game.state.ui.imguiWidth(250),
            .h = game.state.ui.imguiHeight(450),
        });
        for (game.state.ui.world_options.items) |worldOption| {
            var buffer: [ui.max_world_name + 10]u8 = undefined;
            const selectableName = try std.fmt.bufPrint(&buffer, "{d}: {s}", .{ worldOption.id, worldOption.name });
            var name: [ui.max_world_name:0]u8 = undefined;
            for (name, 0..) |_, i| {
                if (selectableName.len <= i) {
                    name[i] = 0;
                    break;
                }
                name[i] = selectableName[i];
            }
            if (zgui.selectable(&name, .{})) {
                try loadWorld(worldOption.id);
            }
        }
        zgui.endListBox();
        zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = game.state.ui.imguiPadding() });
        if (zgui.button("Refresh list", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try listWorlds();
        }
        if (zgui.button("Create world", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try saveWorld();
            const num_worlds = game.state.ui.world_options.items.len;
            const newest_world: data.worldOption = game.state.ui.world_options.items[num_worlds - 1];
            try game.state.initInitialPlayer(
                newest_world.id,
            );
        }
        zgui.pushFont(game.state.ui.codeFont);
        zgui.pushItemWidth(game.state.ui.imguiWidth(250));
        _ = zgui.inputTextWithHint("##Name", .{
            .buf = game.state.ui.world_name_buf[0..],
            .hint = "world name",
        });
        zgui.popItemWidth();
        zgui.popFont();
        if (game.state.ui.world_loaded_id != 0) {
            if (zgui.button("Update world", .{
                .w = btn_dms[0],
                .h = btn_dms[1],
            })) {
                try updateWorld();
            }
            if (zgui.button("Delete world", .{
                .w = btn_dms[0],
                .h = btn_dms[1],
            })) {
                try deleteWorld();
            }
            if (zgui.button("Save chunks", .{
                .w = btn_dms[0],
                .h = btn_dms[1],
            })) {
                try saveChunkDatas();
            }

            if (zgui.button("Generate chunks", .{
                .w = btn_dms[0],
                .h = btn_dms[1],
            })) {
                try evalChunksFunc();
            }
        }
        zgui.popStyleVar(.{ .count = 1 });
    }
    zgui.endChild();
}

fn drawWorldConfig() !void {
    if (zgui.beginChild(
        "Configure World",
        .{
            .w = game.state.ui.imguiWidth(1800),
            .h = game.state.ui.imguiHeight(1000),
            .border = true,
        },
    )) {
        try drawTopDownChunkConfgOptions();
        try drawTopDownChunkConfig();
    }
    zgui.endChild();
}

fn drawTopDownChunkConfgOptions() !void {
    var enum_val: yOptions = .below;
    if (game.state.ui.world_chunk_y == 1) {
        enum_val = .above;
    }
    zgui.setNextItemWidth(game.state.ui.imguiWidth(250));
    if (zgui.comboFromEnum("select y", &enum_val)) {
        if (game.state.ui.world_chunk_y == 1 and enum_val == .below) {
            game.state.ui.world_chunk_y = 0;
            try helpers.loadChunkDatas();
        } else if (game.state.ui.world_chunk_y == 0 and enum_val == .above) {
            game.state.ui.world_chunk_y = 1;
            try helpers.loadChunkDatas();
        }
    }
}

const updateScriptConfigAt = struct {
    wp: chunk.worldPosition,
    script_id: i32,
};

fn drawChunkConfigPopup() !?updateScriptConfigAt {
    var rv: ?updateScriptConfigAt = null;
    if (zgui.beginPopup("ScriptsPicker", .{})) {
        zgui.text("Select a script for this chunk", .{});
        if (zgui.smallButton("delete")) {
            const wp = chunk.worldPosition.initFromPositionV(game.state.ui.world_current_chunk);
            if (game.state.ui.world_chunk_table_data.get(wp)) |ch_cfg| {
                try game.state.db.deleteChunkDataById(ch_cfg.id, game.state.ui.world_loaded_id);
                _ = game.state.ui.world_chunk_table_data.remove(wp);
            }
            zgui.closeCurrentPopup();
        }
        zgui.sameLine(.{ .spacing = zgui.getStyle().item_spacing[0] });
        if (zgui.smallButton("x")) {
            zgui.closeCurrentPopup();
        }
        try listChunkScripts();
        var params: helpers.ScriptOptionsParams = .{
            .w = game.state.ui.imguiWidth(350),
        };
        if (helpers.scriptOptionsListBox(game.state.ui.chunk_script_options, &params)) |scriptOptionId| {
            std.debug.print("selected {d} for chunk at ({d},{d},{d})\n", .{
                scriptOptionId,
                game.state.ui.world_current_chunk[0],
                game.state.ui.world_current_chunk[1],
                game.state.ui.world_current_chunk[2],
            });
            const wp = chunk.worldPosition.initFromPositionV(game.state.ui.world_current_chunk);
            rv = .{ .wp = wp, .script_id = scriptOptionId };
        }
        zgui.endPopup();
    }
    return rv;
}

fn updateChunkConfigFromPopup(updated_script_cfg: ?updateScriptConfigAt) !void {
    if (updated_script_cfg == null) return;
    const cfg = updated_script_cfg.?;
    const wp = cfg.wp;
    const scriptOptionId = cfg.script_id;
    var id: i32 = 0;
    var cd: []u32 = undefined;
    if (game.state.ui.world_chunk_table_data.get(wp)) |ch_cfg| {
        id = ch_cfg.id;
        cd = ch_cfg.chunkData;
    } else {
        cd = try game.state.allocator.alloc(u32, 1);
        cd[0] = 0;
    }
    const ch_cfg: ui.chunkConfig = .{
        .id = id,
        .scriptId = scriptOptionId,
        .chunkData = cd,
    };
    try game.state.ui.world_chunk_table_data.put(wp, ch_cfg);
    var scriptData: data.chunkScript = undefined;
    game.state.db.loadChunkScript(ch_cfg.scriptId, &scriptData) catch unreachable;
    var ch_script = script.Script.dataScriptToScript(scriptData.script);
    _ = game.state.jobs.generateWorldChunk(wp, &ch_script);
}

const chunkConfigInfo = struct {
    col: u32,
    name: [:0]u8,
};

fn drawChunkConfigColumn(p: @Vector(4, f32), w: f32, h: f32) !void {
    const wp = chunk.worldPosition.initFromPositionV(p);
    var info: ?chunkConfigInfo = null;
    if (game.state.ui.world_chunk_table_data.get(wp)) |ch_cfg| {
        for (game.state.ui.chunk_script_options.items) |so| {
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
        const colHeader: [:0]const u8 = try std.fmt.bufPrintZ(&buffer, "{d}_{d}", .{ p[0], p[2] });

        if (zgui.invisibleButton(colHeader, .{
            .w = w,
            .h = h,
        })) {
            game.state.ui.world_current_chunk = p;
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
            pmax = [2]f32{
                pmin[0] + game.state.ui.imguiWidth(25),
                yStart + game.state.ui.imguiHeight(25),
            };
            dl.addRectFilled(.{ .pmin = pmin, .pmax = pmax, .col = ci.col });
            if (hovering and zgui.beginTooltip()) {
                zgui.text("{s}", .{ci.name[0.. :0]});
                zgui.endTooltip();
            }
        }
    }
}

fn drawTopDownChunkConfig() !void {
    const colWidth: f32 = game.state.ui.imguiWidth(750) / config.worldChunkDims;
    if (zgui.beginTable("chunks", .{
        .outer_size = .{
            game.state.ui.imguiWidth(750),
            game.state.ui.imguiHeight(750),
        },
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
        const updated_cfg = try drawChunkConfigPopup();
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
                const p: @Vector(4, f32) = .{
                    @as(f32, @floatFromInt(x)),
                    @as(f32, @floatFromInt(game.state.ui.world_chunk_y)),
                    @as(f32, @floatFromInt(z)),
                    0,
                };
                try drawChunkConfigColumn(p, colWidth, colWidth);
            }
        }
        zgui.endTable();
        try updateChunkConfigFromPopup(updated_cfg);
    }
}

fn evalChunksFunc() !void {
    std.debug.print("GenerateWorldJob: generating world\n", .{});
    var scriptCache = std.AutoHashMap(i32, [script.maxLuaScriptSize]u8).init(game.state.allocator);
    defer scriptCache.deinit();

    var instancedKeys = game.state.ui.world_chunk_table_data.keyIterator();
    while (instancedKeys.next()) |_k| {
        const wp: chunk.worldPosition = _k.*;
        const ch_cfg = game.state.ui.world_chunk_table_data.get(wp).?;
        var ch_script: [script.maxLuaScriptSize]u8 = undefined;
        if (scriptCache.get(ch_cfg.scriptId)) |sc| {
            ch_script = sc;
        } else {
            var scriptData: data.chunkScript = undefined;
            game.state.db.loadChunkScript(ch_cfg.scriptId, &scriptData) catch unreachable;
            ch_script = script.Script.dataScriptToScript(scriptData.script);
            scriptCache.put(ch_cfg.scriptId, ch_script) catch unreachable;
        }
        _ = game.state.jobs.generateWorldChunk(wp, &ch_script);
    }
}

fn saveChunkDatas() !void {
    for (0..config.worldChunkDims) |i| {
        const x: i32 = @as(i32, @intCast(i)) - @as(i32, @intCast(config.worldChunkDims / 2));
        inner: for (0..config.worldChunkDims) |ii| {
            const z: i32 = @as(i32, @intCast(ii)) - @as(i32, @intCast(config.worldChunkDims / 2));
            const y = game.state.ui.world_chunk_y;
            const p = @Vector(4, f32){
                @as(f32, @floatFromInt(x)),
                @as(f32, @floatFromInt(y)),
                @as(f32, @floatFromInt(z)),
                0,
            };
            const wp = chunk.worldPosition.initFromPositionV(p);
            if (game.state.ui.world_chunk_table_data.get(wp)) |ch_cfg| {
                if (ch_cfg.id != 0) {
                    // update
                    try game.state.db.updateChunkData(
                        ch_cfg.id,
                        ch_cfg.scriptId,
                        ch_cfg.chunkData,
                    );
                    continue :inner;
                }
                // insert
                try game.state.db.saveChunkData(
                    game.state.ui.world_loaded_id,
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

const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const config = @import("../../../config.zig");
const data = @import("../../../data/data.zig");
const game_state = @import("../../../state.zig");
const ui = @import("../../../ui.zig");
const helpers = @import("ui_helpers.zig");
const script = @import("../../../script/script.zig");
const block = @import("../../../block/block.zig");
const chunk = block.chunk;
