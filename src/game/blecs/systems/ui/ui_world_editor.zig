const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const gl = @import("zopengl").bindings;
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const helpers = @import("../../helpers.zig");
const game = @import("../../../game.zig");
const config = @import("../../../config.zig");
const chunk = @import("../../../chunk.zig");
const data = @import("../../../data/data.zig");
const game_state = @import("../../../state/game.zig");
const state = @import("../../../state/state.zig");
const menus = @import("../../../ui/menus.zig");
const script = @import("../../../script/script.zig");

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
                drawWorldOptions() catch unreachable;
                if (game.state.ui.data.world_loaded_id != 0) {
                    zgui.sameLine(.{});
                    drawWorldConfig() catch unreachable;
                }
            }
            zgui.end();
        }
    }
}

fn listChunkScripts() !void {
    try game.state.db.listChunkScripts(&game.state.ui.data.chunk_script_options);
}

fn listWorlds() !void {
    try game.state.db.listWorlds(&game.state.ui.data.world_options);
}

fn saveWorld() !void {
    const n = std.mem.indexOf(u8, &game.state.ui.data.world_name_buf, &([_]u8{0}));
    if (n) |i| {
        if (i < 3) {
            std.log.err("World name is too short", .{});
            return;
        }
    }
    try game.state.db.saveWorld(&game.state.ui.data.world_name_buf);
    try listWorlds();
}

fn loadWorld(worldId: i32) !void {
    var worldData: data.world = undefined;
    try game.state.db.loadWorld(worldId, &worldData);
    var nameBuf = [_]u8{0} ** game_state.max_world_name;
    for (worldData.name, 0..) |c, i| {
        if (i >= game_state.max_world_name) {
            break;
        }
        nameBuf[i] = c;
    }
    game.state.ui.data.world_name_buf = nameBuf;
    game.state.ui.data.world_loaded_id = worldId;
    try loadChunkDatas();
}

fn updateWorld() !void {
    const n = std.mem.indexOf(u8, &game.state.ui.data.world_name_buf, &([_]u8{0}));
    if (n) |i| {
        if (i < 3) {
            std.log.err("World name is too short", .{});
            return;
        }
    }
    const id = @as(i32, @intCast(game.state.ui.data.world_loaded_id));
    try game.state.db.updateWorld(id, &game.state.ui.data.world_name_buf);
    try listWorlds();
    try loadWorld(id);
}

fn deleteWorld() !void {
    const id = @as(i32, @intCast(game.state.ui.data.world_loaded_id));
    try game.state.db.deleteWorld(id);
    try listWorlds();
    game.state.ui.data.world_loaded_id = 0;
}

fn drawWorldOptions() !void {
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
        for (game.state.ui.data.world_options.items) |worldOption| {
            var buffer: [game_state.max_world_name + 10]u8 = undefined;
            const selectableName = try std.fmt.bufPrint(&buffer, "{d}: {s}", .{ worldOption.id, worldOption.name });
            var name: [game_state.max_world_name:0]u8 = undefined;
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
        zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
        if (zgui.button("Refresh list", .{
            .w = 500,
            .h = 100,
        })) {
            try listWorlds();
        }
        if (zgui.button("Create world", .{
            .w = 500,
            .h = 100,
        })) {
            try saveWorld();
        }
        zgui.pushFont(game.state.ui.codeFont);
        zgui.pushItemWidth(500);
        _ = zgui.inputTextWithHint("##Name", .{
            .buf = game.state.ui.data.world_name_buf[0..],
            .hint = "world name",
        });
        zgui.popItemWidth();
        zgui.popFont();
        if (game.state.ui.data.world_loaded_id != 0) {
            if (zgui.button("Update world", .{
                .w = 500,
                .h = 100,
            })) {
                try updateWorld();
            }
            if (zgui.button("Delete world", .{
                .w = 500,
                .h = 100,
            })) {
                try deleteWorld();
            }
            if (zgui.button("Save chunks", .{
                .w = 500,
                .h = 100,
            })) {
                try saveChunkDatas();
            }

            if (zgui.button("Generate chunks", .{
                .w = 500,
                .h = 100,
            })) {
                try evalChunksFunc();
            }

            if (zgui.button("Load world", .{
                .w = 500,
                .h = 100,
            })) {
                try loadChunksInWorld();
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
            .w = 3250,
            .h = 2100,
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
    if (game.state.ui.data.world_chunk_y == 1) {
        enum_val = .above;
    }
    zgui.setNextItemWidth(500);
    if (zgui.comboFromEnum("select y", &enum_val)) {
        if (game.state.ui.data.world_chunk_y == 1 and enum_val == .below) {
            game.state.ui.data.world_chunk_y = 0;
            try loadChunkDatas();
        } else if (game.state.ui.data.world_chunk_y == 0 and enum_val == .above) {
            game.state.ui.data.world_chunk_y = 1;
            try loadChunkDatas();
        }
    }
}

fn drawChunkConfigPopup() !void {
    if (zgui.beginPopup("ScriptsPicker", .{})) {
        zgui.text("Select a script for this chunk", .{});
        if (zgui.smallButton("x")) {
            zgui.closeCurrentPopup();
        }
        try listChunkScripts();
        if (menus.scriptOptionsListBox(game.state.ui.data.chunk_script_options, .{ .w = 700 })) |scriptOptionId| {
            std.debug.print("selected {d} for chunk at ({d},{d},{d})\n", .{
                scriptOptionId,
                game.state.ui.data.world_current_chunk[0],
                game.state.ui.data.world_current_chunk[1],
                game.state.ui.data.world_current_chunk[2],
            });
            const wp = state.position.worldPosition.initFromPositionV(game.state.ui.data.world_current_chunk);

            var id: i32 = 0;
            var cd: []i32 = undefined;
            if (game.state.ui.data.world_chunk_table_data.get(wp)) |ch_cfg| {
                id = ch_cfg.id;
                cd = ch_cfg.chunkData;
            } else {
                return;
            }
            const ch_cfg: game_state.chunkConfig = .{
                .id = id,
                .scriptId = scriptOptionId,
                .chunkData = cd,
            };
            try game.state.ui.data.world_chunk_table_data.put(wp, ch_cfg);
        }
        zgui.endPopup();
    }
}

const chunkConfigInfo = struct {
    col: u32,
    name: [:0]u8,
};

fn drawChunkConfigColumn(p: @Vector(4, gl.Float), w: f32, h: f32) !void {
    const wp = state.position.worldPosition.initFromPositionV(p);
    var info: ?chunkConfigInfo = null;
    if (game.state.ui.data.world_chunk_table_data.get(wp)) |ch_cfg| {
        for (game.state.ui.data.chunk_script_options.items) |so| {
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
            game.state.ui.data.world_current_chunk = p;
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

fn drawTopDownChunkConfig() !void {
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
        try drawChunkConfigPopup();
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
                const p: @Vector(4, gl.Float) = .{
                    @as(gl.Float, @floatFromInt(x)),
                    @as(gl.Float, @floatFromInt(game.state.ui.data.world_chunk_y)),
                    @as(gl.Float, @floatFromInt(z)),
                    0,
                };
                try drawChunkConfigColumn(p, colWidth, colWidth);
            }
        }
        zgui.endTable();
    }
}

fn loadChunksInWorld() !void {
    const world = game.state.world;
    entities.screen.clearWorld();
    var instancedKeys = game.state.ui.data.world_chunk_table_data.keyIterator();
    while (instancedKeys.next()) |_k| {
        if (@TypeOf(_k) == *state.position.worldPosition) {
            const wp: state.position.worldPosition = _k.*;
            const ch_cfg = game.state.ui.data.world_chunk_table_data.get(wp).?;
            const p = wp.vecFromWorldPosition();

            var c: *chunk.Chunk = chunk.Chunk.init(game.state.allocator) catch unreachable;

            c.data = try game.state.allocator.alloc(i32, ch_cfg.chunkData.len);
            @memcpy(c.data, ch_cfg.chunkData);
            const chunk_entity = helpers.new_child(world, entities.screen.game_data);
            _ = ecs.set(world, chunk_entity, components.block.Chunk, .{
                .loc = .{
                    p[0] * chunk.chunkDim,
                    p[1] * chunk.chunkDim,
                    p[2] * chunk.chunkDim,
                    0,
                },
            });
            ecs.add(world, chunk_entity, components.block.NeedsMeshing);
            game.state.gfx.mesh_data.put(chunk_entity, c) catch unreachable;
        }
    }
}

fn evalChunksFunc() !void {
    var scriptCache = std.AutoHashMap(i32, [script.maxLuaScriptSize]u8).init(game.state.allocator);
    defer scriptCache.deinit();

    var instancedKeys = game.state.ui.data.world_chunk_table_data.keyIterator();
    while (instancedKeys.next()) |_k| {
        const wp: state.position.worldPosition = _k.*;
        var ch_cfg = game.state.ui.data.world_chunk_table_data.get(wp).?;
        var ch_script: [script.maxLuaScriptSize]u8 = undefined;
        if (scriptCache.get(ch_cfg.scriptId)) |sc| {
            ch_script = sc;
        } else {
            var scriptData: data.chunkScript = undefined;
            try game.state.db.loadChunkScript(ch_cfg.scriptId, &scriptData);
            ch_script = script.Script.dataScriptToScript(scriptData.script);
            try scriptCache.put(ch_cfg.scriptId, ch_script);
        }
        const c_data = game.state.script.evalChunkFunc(ch_script) catch |err| {
            std.debug.print("Error evaluating chunk in eval chunks function: {}\n", .{err});
            return;
        };
        ch_cfg.chunkData = c_data;
        if (game.state.ui.data.world_chunk_table_data.get(wp)) |cd| {
            game.state.allocator.free(cd.chunkData);
        }
        try game.state.ui.data.world_chunk_table_data.put(wp, ch_cfg);
    }
}

fn saveChunkDatas() !void {
    for (0..config.worldChunkDims) |i| {
        const x: i32 = @as(i32, @intCast(i)) - @as(i32, @intCast(config.worldChunkDims / 2));
        inner: for (0..config.worldChunkDims) |ii| {
            const z: i32 = @as(i32, @intCast(ii)) - @as(i32, @intCast(config.worldChunkDims / 2));
            const y = game.state.ui.data.world_chunk_y;
            const p = state.position.Position{
                .x = @as(f32, @floatFromInt(x)),
                .y = @as(f32, @floatFromInt(y)),
                .z = @as(f32, @floatFromInt(z)),
            };
            const wp = state.position.worldPosition.initFromPosition(p);
            if (game.state.ui.data.world_chunk_table_data.get(wp)) |ch_cfg| {
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
                    game.state.ui.data.world_loaded_id,
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

fn loadChunkDatas() !void {
    var td = game.state.ui.data.world_chunk_table_data.valueIterator();
    while (td.next()) |cc| {
        game.state.allocator.free(cc.*.chunkData);
    }
    game.state.ui.data.world_chunk_table_data.clearAndFree();
    for (0..2) |_i| {
        const y: i32 = @as(i32, @intCast(_i));
        for (0..config.worldChunkDims) |i| {
            const x: i32 = @as(i32, @intCast(i)) - @as(i32, @intCast(config.worldChunkDims / 2));
            for (0..config.worldChunkDims) |ii| {
                const z: i32 = @as(i32, @intCast(ii)) - @as(i32, @intCast(config.worldChunkDims / 2));
                var chunkData = data.chunkData{};
                game.state.db.loadChunkData(game.state.ui.data.world_loaded_id, x, y, z, &chunkData) catch |err| {
                    if (err == data.DataErr.NotFound) {
                        continue;
                    }
                    return err;
                };
                const p = state.position.Position{
                    .x = @as(gl.Float, @floatFromInt(x)),
                    .y = @as(gl.Float, @floatFromInt(y)),
                    .z = @as(gl.Float, @floatFromInt(z)),
                };
                const wp = state.position.worldPosition.initFromPosition(p);
                const cfg = game_state.chunkConfig{
                    .id = chunkData.id,
                    .scriptId = chunkData.scriptId,
                    .chunkData = chunkData.voxels,
                };
                try game.state.ui.data.world_chunk_table_data.put(wp, cfg);
            }
        }
    }
}
