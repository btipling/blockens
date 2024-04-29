const default_pos: @Vector(4, f32) = .{ 0, 0, 0, 0 };
pub const PlayerPosition = struct {
    loc: @Vector(4, f32) = default_pos,
    rotation: @Vector(4, f32) = .{ 0, 0, 0, 0 },
    angle: f32 = 0,
};
pub const ChunkColumn = struct {
    x: i8,
    z: i8,
};
pub const SaveData = struct {
    player_position: PlayerPosition,
    chunks_updated: [2]?ChunkColumn = [_]?ChunkColumn{ null, null }, // limit chunk saves per save
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
        for (self.data.chunks_updated) |cc| {
            std.debug.print("saving chunk in save jobs wtf\n", .{});
            if (cc) |c| self.saveChunk(c) catch @panic("nope");
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

    fn saveChunk(_: *@This(), cc: ChunkColumn) !void {
        const top_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
        defer game.state.allocator.free(top_chunk);
        const bottom_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
        defer game.state.allocator.free(bottom_chunk);
        const x: f32 = @floatFromInt(cc.x);
        const z: f32 = @floatFromInt(cc.z);
        const p_t = @Vector(4, f32){ x, 1, z, 0 };
        const p_b = @Vector(4, f32){ x, 0, z, 0 };
        const wp_t = chunk.worldPosition.initFromPositionV(p_t);
        const wp_b = chunk.worldPosition.initFromPositionV(p_b);

        if (game.state.blocks.game_chunks.get(wp_t)) |c| {
            c.mutex.lock();
            defer c.mutex.unlock();
            var ci: usize = 0;
            while (ci < chunk.chunkSize) : (ci += 1) top_chunk[ci] = @intCast(c.data[ci]);
            c.updated = false;
        } else {
            var ci: usize = 0;
            while (ci < chunk.chunkSize) : (ci += 1) top_chunk[ci] = big_chunk.fully_lit_chunk[ci];
        }
        if (game.state.blocks.game_chunks.get(wp_b)) |c| {
            c.mutex.lock();
            defer c.mutex.unlock();
            var ci: usize = 0;
            while (ci < chunk.chunkSize) : (ci += 1) bottom_chunk[ci] = @intCast(c.data[ci]);
            c.updated = false;
        } else {
            var ci: usize = 0;
            while (ci < chunk.chunkSize) : (ci += 1) bottom_chunk[ci] = big_chunk.fully_lit_chunk[ci];
        }
        data.chunk_file.saveChunkData(
            game.state.allocator,
            game.state.ui.world_loaded_id,
            @intCast(cc.x),
            @intCast(cc.z),
            top_chunk,
            bottom_chunk,
        );
    }
};

const std = @import("std");
const game = @import("../../game.zig");
const blecs = @import("../../blecs/blecs.zig");
const data = @import("../../data/data.zig");
const config = @import("config");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
const big_chunk = chunk.big;
