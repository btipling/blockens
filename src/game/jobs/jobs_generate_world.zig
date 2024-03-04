const std = @import("std");
const game = @import("../game.zig");
const state = @import("../state/state.zig");
const data = @import("../data/data.zig");
const script = @import("../script/script.zig");
const blecs = @import("../blecs/blecs.zig");

pub const GenerateWorldJob = struct {
    pub fn exec(_: *@This()) void {
        game.state.ui.data.world_load_disabled = true;
        std.debug.print("GenerateWorldJob: generating world\n", .{});
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
                game.state.db.loadChunkScript(ch_cfg.scriptId, &scriptData) catch unreachable;
                ch_script = script.Script.dataScriptToScript(scriptData.script);
                scriptCache.put(ch_cfg.scriptId, ch_script) catch unreachable;
            }
            const c_data = game.state.script.evalChunkFunc(ch_script) catch |err| {
                std.debug.print("Error evaluating chunk in eval chunks function: {}\n", .{err});
                return;
            };
            ch_cfg.chunkData = c_data;
            if (game.state.ui.data.world_chunk_table_data.get(wp)) |cd| {
                game.state.allocator.free(cd.chunkData);
            }
            game.state.ui.data.world_chunk_table_data.put(wp, ch_cfg) catch unreachable;
        }
        game.state.ui.data.world_load_disabled = false;
    }
};
