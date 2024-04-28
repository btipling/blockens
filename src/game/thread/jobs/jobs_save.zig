const default_pos: @Vector(4, f32) = .{ 0, 0, 0, 0 };
pub const PlayerPosition = struct {
    loc: @Vector(4, f32) = default_pos,
    rotation: @Vector(4, f32) = .{ 0, 0, 0, 0 },
    angle: f32 = 0,
};
pub const SaveData = struct {
    player_position: PlayerPosition,
    chunks_updated: [2]?*chunk.Chunk = [2]?*chunk.Chunk{ null, null }, // limit chunk saves per save
};

pub const SaveJob = struct {
    data: SaveData,
    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("SaveJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "SaveJob", 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.saveJob();
        } else {
            self.saveJob();
        }
    }

    pub fn saveJob(self: *@This()) void {
        self.savePlayerPosition() catch std.debug.print("unable to save player position\n", .{});
        for (self.data.chunks_updated) |mc| {
            if (mc) |c| self.saveChunk(c) catch @panic("nope");
        }
    }

    fn savePlayerPosition(self: *@This()) !void {
        const loaded_world = game.state.ui.world_loaded_id;
        const pp = self.data.player_position;
        const pl: [4]f32 = pp.loc;
        const dp: [4]f32 = default_pos;
        if (std.mem.eql(f32, pl[0..], dp[0..])) return; // don't save unset player position
        try game.state.db.updatePlayerPosition(loaded_world, pp.loc, pp.rotation, pp.angle);
    }

    fn saveChunk(self: *@This(), c: *chunk.Chunk) !void {
        if (!c.updated) return;
        var voxels: []u32 = undefined;
        const wp: chunk.worldPosition = c.wp;
        {
            c.mutex.lock();
            defer c.mutex.unlock();
            voxels = game.state.allocator.dupe(u32, c.data) catch @panic("OOM");
            c.updated = false;
        }
        return self._saveChunk(voxels, wp);
    }

    fn _saveChunk(_: *@This(), voxels: []u32, wp: chunk.worldPosition) !void {
        defer game.state.allocator.free(voxels);
        var c_cfg = game.state.ui.world_chunk_table_data.get(wp) orelse return;
        const loaded_world = game.state.ui.world_loaded_id;
        if (c_cfg.id == 0) {
            // save new chunk
            const p = chunk.worldPosition.vecFromWorldPosition(wp);
            const x: i32 = @intFromFloat(@floor(p[0]));
            const y: i32 = @intFromFloat(@floor(p[1]));
            const z: i32 = @intFromFloat(@floor(p[2]));
            try game.state.db.saveChunkData(loaded_world, x, y, z, c_cfg.scriptId, voxels);
            var db_chunk_data: data.chunkData = .{};
            try game.state.db.loadChunkData(loaded_world, x, y, z, &db_chunk_data);
            c_cfg.id = db_chunk_data.id;
            game.state.allocator.free(c_cfg.chunkData);
            c_cfg.chunkData = db_chunk_data.voxels;
            try game.state.ui.world_chunk_table_data.put(wp, c_cfg);
            std.debug.print("new chunk saved\n", .{});
        } else {
            // update existing chunk
            try game.state.db.updateChunkData(c_cfg.id, c_cfg.scriptId, voxels);
            std.debug.print("updated chunk saved\n", .{});
        }
    }
};

const std = @import("std");
const game = @import("../../game.zig");
const blecs = @import("../../blecs/blecs.zig");
const data = @import("../../data/data.zig");
const config = @import("config");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
