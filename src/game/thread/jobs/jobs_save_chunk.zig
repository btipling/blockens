const default_pos: @Vector(4, f32) = .{ 0, 0, 0, 0 };

pub const SaveChunkJob = struct {
    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("SaveChunkJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "SaveCHunkJob", 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.saveChunkJob();
        } else {
            self.saveChunkJob();
        }
    }

    fn saveChunkJob(self: *@This()) void {
        const ccl: []buffer.ChunkColumn = buffer.get_updated_chunks();
        defer game.state.allocator.free(ccl);
        for (ccl) |cc| self.saveChunkColumn(cc);
    }

    fn saveChunkColumn(_: @This(), cc: buffer.ChunkColumn) void {
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
            @memset(top_chunk, chunk.big.fully_lit_air_voxel);
        }
        if (game.state.blocks.game_chunks.get(wp_b)) |c| {
            c.mutex.lock();
            defer c.mutex.unlock();
            var ci: usize = 0;
            while (ci < chunk.chunkSize) : (ci += 1) bottom_chunk[ci] = @intCast(c.data[ci]);
            c.updated = false;
        } else {
            @memset(bottom_chunk, chunk.big.fully_lit_air_voxel);
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
const buffer = @import("../buffer.zig");
const config = @import("config");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
