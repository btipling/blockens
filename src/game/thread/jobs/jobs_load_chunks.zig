const air: u8 = 0;
const max_trigger_depth: u8 = 3;

pub const LoadChunkJob = struct {
    world_id: i32,
    x: i32,
    z: i32,
    start_game: bool,
    pt: *buffer.ProgressTracker,

    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("LoadChunkJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "LoadChunkJob", 0x00_C5_82_f0);
            defer tracy_zone.End();
            self.loadChunkJob();
        } else {
            self.loadChunkJob();
        }
    }

    fn loadChunkJob(self: @This()) void {
        const x: i32 = self.x;
        const z: i32 = self.z;
        const w_id = self.world_id;
        var chunkDataTop: data.chunkData = .{};
        var chunkDataBot: data.chunkData = .{};
        const _x: f32 = @floatFromInt(x);
        const _z: f32 = @floatFromInt(z);
        const p_t = @Vector(4, f32){ _x, 1, _z, 0 };
        const p_b = @Vector(4, f32){ _x, 0, _z, 0 };
        const wp_t = chunk.worldPosition.initFromPositionV(p_t);
        const wp_b = chunk.worldPosition.initFromPositionV(p_b);
        game.state.db.loadChunkMetadata(w_id, x, 1, z, &chunkDataTop) catch |err| {
            if (err != data.DataErr.NotFound) {
                std.debug.panic("unable to load chunk datas ({d}, 1, {d}): {}\n", .{ x, z, err });
            }
            self.finishJob(false, wp_t, wp_b, .{}, .{});
            return;
        };
        game.state.db.loadChunkMetadata(w_id, x, 0, z, &chunkDataBot) catch |err| {
            if (err != data.DataErr.NotFound) {
                std.log.err("unable to load chunk datas ({d}, 0, {d}): {}\n", .{ x, z, err });
                return;
            }
            self.finishJob(false, wp_t, wp_b, .{}, .{});
            return;
        };
        const top_chunk_small: []u32 = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
        errdefer game.state.allocator.free(chunkDataTop.voxels);
        const bot_chunk_small: []u32 = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
        errdefer game.state.allocator.free(chunkDataBot.voxels);
        {
            const top_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
            defer game.state.allocator.free(top_chunk);
            const bottom_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
            defer game.state.allocator.free(bottom_chunk);
            data.chunk_file.loadChunkData(
                game.state.allocator,
                w_id,
                x,
                z,
                top_chunk,
                bottom_chunk,
            ) catch |err| {
                std.debug.panic("loaded invalid chunk x: {d} z: {d} {}\n", .{ x, z, err });
            };
            var ci: usize = 0;
            while (ci < chunk.chunkSize) : (ci += 1) {
                top_chunk_small[ci] = @truncate(top_chunk[ci]);
                bot_chunk_small[ci] = @truncate(bottom_chunk[ci]);
            }
        }

        const cfg_t = ui.chunkConfig{
            .id = chunkDataTop.id,
            .scriptId = chunkDataTop.scriptId,
            .chunkData = top_chunk_small,
        };
        const cfg_b = ui.chunkConfig{
            .id = chunkDataBot.id,
            .scriptId = chunkDataBot.scriptId,
            .chunkData = bot_chunk_small,
        };
        self.finishJob(true, wp_t, wp_b, cfg_t, cfg_b);
    }

    fn finishJob(
        self: @This(),
        exists: bool,
        wp_t: chunk.worldPosition,
        wp_b: chunk.worldPosition,
        cfg_t: ui.chunkConfig,
        cfg_b: ui.chunkConfig,
    ) void {
        var msg: buffer.buffer_message = buffer.new_message(.load_chunk);
        const done: bool, const num_started: usize, const num_done: usize = self.pt.completeOne();
        if (done) game.state.allocator.destroy(self.pt);
        const ns: f16 = @floatFromInt(num_started);
        const nd: f16 = @floatFromInt(num_done);
        const pr: f16 = nd / ns;
        buffer.set_progress(
            &msg,
            done,
            pr,
        );
        const bd: buffer.buffer_data = .{
            .load_chunk = .{
                .world_id = self.world_id,
                .x = self.x,
                .z = self.z,
                .wp_t = wp_t,
                .wp_b = wp_b,
                .cfg_t = cfg_t,
                .cfg_b = cfg_b,
                .exists = exists,
                .start_game = self.start_game,
            },
        };
        buffer.put_data(msg, bd) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("unable to write message");
    }
};

const std = @import("std");
const ui = @import("../../ui.zig");
const game = @import("../../game.zig");
const data = @import("../../data/data.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
