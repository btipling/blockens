const std = @import("std");
const zgui = @import("zgui");
const config = @import("../../../config.zig");
const data = @import("../../../data/data.zig");
const game = @import("../../../game.zig");
const entities = @import("../../entities/entities.zig");
const game_state = @import("../../../state/state.zig");
const script = @import("../../../script/script.zig");

const ScriptOptionsParams = struct {
    w: f32 = 500.0,
    h: f32 = 900.0,
};

pub fn scriptOptionsListBox(scriptOptions: std.ArrayList(data.chunkScriptOption), params: ScriptOptionsParams) ?i32 {
    var rv: ?i32 = null;
    if (zgui.beginListBox("##chunk_script_options", .{
        .w = params.w,
        .h = params.h,
    })) {
        zgui.pushStyleColor4f(.{ .idx = .header_hovered, .c = .{ 1.0, 1.0, 1.0, 0.25 } });
        for (scriptOptions.items) |scriptOption| {
            var buffer: [script.maxLuaScriptNameSize + 10]u8 = undefined;

            var sn = scriptOption.name;
            var st: usize = 0;
            for (0..scriptOption.name.len) |i| {
                if (scriptOption.name[i] == 0) {
                    st = i;
                    break;
                }
            }
            if (st == 0) {
                break;
            }
            var name = std.fmt.bufPrintZ(&buffer, "  {d}: {s}", .{ scriptOption.id, sn[0..st :0] }) catch {
                std.debug.print("unable to write selectable name.\n", .{});
                continue;
            };
            _ = &name;
            var dl = zgui.getWindowDrawList();
            const pmin = zgui.getCursorScreenPos();
            const pmax = [2]f32{ pmin[0] + 35.0, pmin[1] + 30.0 };
            const col = zgui.colorConvertFloat4ToU32(.{ scriptOption.color[0], scriptOption.color[1], scriptOption.color[2], 1.0 });
            dl.addRectFilled(.{ .pmin = pmin, .pmax = pmax, .col = col });

            if (zgui.selectable(name, .{ .h = 60 })) {
                rv = scriptOption.id;
            }
        }
        zgui.popStyleColor(.{ .count = 1 });
        zgui.endListBox();
    }
    return rv;
}

pub fn loadChunksInWorld() void {
    entities.screen.clearWorld();
    var instancedKeys = game.state.ui.data.world_chunk_table_data.keyIterator();
    while (instancedKeys.next()) |_k| {
        _ = game.state.jobs.copyChunk(_k.*);
    }
}

pub fn loadCharacterInWorld() void {
    entities.screen.initPlayerCharacter();
}

pub fn loadChunkDatas() !void {
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
                const p = @Vector(4, f32){
                    @as(f32, @floatFromInt(x)),
                    @as(f32, @floatFromInt(y)),
                    @as(f32, @floatFromInt(z)),
                    0,
                };
                const wp = game_state.position.worldPosition.initFromPositionV(p);
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
