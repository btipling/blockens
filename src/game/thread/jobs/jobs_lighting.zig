pub const LightingJob = struct {
    world_id: i32,
    x: i32,
    z: i32,
    pt: *buffer.ProgressTracker,

    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("LightingJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "LightingJob", 0x00_C0_82_f0);
            defer tracy_zone.End();
            self.lightingJob();
        } else {
            self.lightingJob();
        }
    }

    fn cData(self: @This(), x: i32, z: i32, required: bool) !struct { []u32, []u32 } {
        const top_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
        defer game.state.allocator.free(top_chunk);
        const bottom_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
        defer game.state.allocator.free(bottom_chunk);
        data.chunk_file.loadChunkData(
            game.state.allocator,
            self.world_id,
            x,
            z,
            top_chunk,
            bottom_chunk,
        ) catch |err| {
            if (required) {
                return err;
            }
            @memset(top_chunk, 0);
            @memset(bottom_chunk, 0);
        };
        const t_block_data: []u32 = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
        const bt_block_data: []u32 = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
        var ci: usize = 0;
        while (ci < chunk.chunkSize) : (ci += 1) {
            t_block_data[ci] = @truncate(top_chunk[ci]);
            bt_block_data[ci] = @truncate(bottom_chunk[ci]);
        }
        return .{ t_block_data, bt_block_data };
    }

    pub fn lightingJob(self: *@This()) void {
        const t_data: []u32, const b_data: []u32 = self.cData(self.x, self.z, true) catch {
            self.finishJob();
            return;
        };
        defer game.state.allocator.free(t_data);
        defer game.state.allocator.free(b_data);

        lighting.light_fall(t_data, b_data);
        {
            const top_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
            defer game.state.allocator.free(top_chunk);
            const bottom_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
            defer game.state.allocator.free(bottom_chunk);
            var i: usize = 0;
            while (i < chunk.chunkSize) : (i += 1) {
                top_chunk[i] = @intCast(t_data[i]);
                bottom_chunk[i] = @intCast(b_data[i]);
            }
            data.chunk_file.saveChunkData(
                game.state.allocator,
                self.world_id,
                self.x,
                self.z,
                top_chunk,
                bottom_chunk,
            );
        }
        self.finishJob();
    }

    fn finishJob(self: *LightingJob) void {
        var msg: buffer.buffer_message = buffer.new_message(.lighting);
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
            .lighting = .{
                .world_id = self.world_id,
                .x = self.x,
                .z = self.z,
            },
        };
        buffer.put_data(msg, bd) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("unable to write message");
    }
};

const std = @import("std");
const game = @import("../../game.zig");
const data = @import("../../data/data.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");
const lighting = @import("../../block/lighting_ambient_fall.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
