pub const ScriptOptionsParams = struct {
    w: f32 = 0,
    h: f32 = 0,
};

pub fn scriptOptionsListBox(scriptOptions: std.ArrayList(data.chunkScriptOption), params: *ScriptOptionsParams) ?i32 {
    if (params.w == 0) params.w = game.state.ui.imguiWidth(250);
    if (params.h == 0) params.h = game.state.ui.imguiWidth(450);
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
            const pmax = [2]f32{
                pmin[0] + game.state.ui.imguiWidth(10),
                pmin[1] + game.state.ui.imguiHeight(10),
            };
            const col = zgui.colorConvertFloat4ToU32(.{ scriptOption.color[0], scriptOption.color[1], scriptOption.color[2], 1.0 });
            dl.addRectFilled(.{ .pmin = pmin, .pmax = pmax, .col = col });

            if (zgui.selectable(name, .{ .h = game.state.ui.imguiHeight(30) })) {
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
    var instancedKeys = game.state.ui.world_chunk_table_data.keyIterator();
    while (instancedKeys.next()) |_k| {
        _ = game.state.jobs.copyChunk(_k.*, ecs.new_id(game.state.world), false, false);
    }
}

pub fn loadCharacterInWorld() void {
    entities.screen.initPlayerCharacter();
    entities.screen.initBlockHighlight();
}

pub fn loadChunkDatas() !void {
    var td = game.state.ui.world_chunk_table_data.valueIterator();
    while (td.next()) |cc| {
        game.state.allocator.free(cc.*.chunkData);
    }
    game.state.ui.world_chunk_table_data.clearAndFree();
    const w_id: i32 = game.state.ui.world_loaded_id;
    for (0..config.worldChunkDims) |i| {
        const x: i32 = @as(i32, @intCast(i)) - @as(i32, @intCast(config.worldChunkDims / 2));
        for (0..config.worldChunkDims) |ii| {
            const z: i32 = @as(i32, @intCast(ii)) - @as(i32, @intCast(config.worldChunkDims / 2));
            var chunkDataTop: data.chunkData = .{};
            var chunkDataBot: data.chunkData = .{};
            game.state.db.loadChunkData(w_id, x, 1, z, &chunkDataTop) catch |err| {
                if (err != data.DataErr.NotFound) return err;
                chunkDataTop.voxels = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
            };
            game.state.db.loadChunkData(w_id, x, 0, z, &chunkDataBot) catch |err| {
                if (err != data.DataErr.NotFound) return err;
                chunkDataBot.voxels = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
            };
            const _x: f32 = @floatFromInt(x);
            const _z: f32 = @floatFromInt(z);
            const p_t = @Vector(4, f32){ _x, 1, _z, 0 };
            const p_b = @Vector(4, f32){ _x, 0, _z, 0 };
            const wp_t = chunk.worldPosition.initFromPositionV(p_t);
            const wp_b = chunk.worldPosition.initFromPositionV(p_b);
            {
                const top_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
                defer game.state.allocator.free(top_chunk);
                const bottom_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
                defer game.state.allocator.free(bottom_chunk);
                data.chunk_file.loadChunkData(game.state.allocator, w_id, x, z, top_chunk, bottom_chunk);
                var ci: usize = 0;
                while (ci < chunk.chunkSize) : (ci += 1) {
                    chunkDataTop.voxels[ci] = @truncate(top_chunk[ci]);
                    chunkDataBot.voxels[ci] = @truncate(bottom_chunk[ci]);
                }
            }

            const cfg_t = ui.chunkConfig{
                .id = chunkDataTop.id,
                .scriptId = chunkDataTop.scriptId,
                .chunkData = chunkDataTop.voxels,
            };
            const cfg_b = ui.chunkConfig{
                .id = chunkDataBot.id,
                .scriptId = chunkDataBot.scriptId,
                .chunkData = chunkDataBot.voxels,
            };
            try game.state.ui.world_chunk_table_data.put(wp_t, cfg_t);
            try game.state.ui.world_chunk_table_data.put(wp_b, cfg_b);
        }
    }
}

const std = @import("std");
const zgui = @import("zgui");
const ecs = @import("zflecs");
const config = @import("../../../config.zig");
const data = @import("../../../data/data.zig");
const game = @import("../../../game.zig");
const entities = @import("../../entities/entities.zig");
const ui = @import("../../../ui.zig");
const script = @import("../../../script/script.zig");
const block = @import("../../../block/block.zig");
const chunk = block.chunk;
