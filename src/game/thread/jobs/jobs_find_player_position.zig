pub const FindPlayerPositionJob = struct {
    world_id: i32,
    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("FindPlayerPositionJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "FindPlayerPositionJob", 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.findPlayerPositionJob();
        } else {
            self.findPlayerPositionJob();
        }
    }

    pub fn findPlayerPositionJob(self: *FindPlayerPositionJob) void {
        std.debug.print("finding player position\n", .{});
        const loaded_world = game.state.ui.world_loaded_id;

        const top_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
        defer game.state.allocator.free(top_chunk);
        const bottom_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
        defer game.state.allocator.free(bottom_chunk);
        data.chunk_file.loadChunkData(
            game.state.allocator,
            self.world_id,
            0,
            0,
            top_chunk,
            bottom_chunk,
        ) catch @panic("file load error");
        const t_block_data: []u32 = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
        const bt_block_data: []u32 = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
        {
            var ci: usize = 0;
            while (ci < chunk.chunkSize) : (ci += 1) {
                t_block_data[ci] = @truncate(top_chunk[ci]);
                bt_block_data[ci] = @truncate(bottom_chunk[ci]);
            }
        }
        defer game.state.allocator.free(t_block_data);
        defer game.state.allocator.free(bt_block_data);

        var pp: @Vector(4, f32) = .{ 32, 0, 32, 0 };
        {
            // find player position
            var i: usize = chunk.chunkDim - 1;
            var set = false;
            while (i > 0) : (i -= 1) {
                pp[1] = @as(f32, @floatFromInt(i)) + 64.0;
                const pos = chunk.chunkBlockPosFromWorldLocation(pp);
                const ci = chunk.getIndexFromPositionV(pos);
                const bd: block.BlockData = block.BlockData.fromId(t_block_data[ci]);
                if (bd.block_id != 0) {
                    set = true;
                    break;
                }
            }
            if (!set) {
                pp[1] = 64;
            }
        }

        game.state.db.savePlayerPosition(
            loaded_world,
            pp,
            .{ 0, -0.779, 0, 0.6281 },
            639.098,
        ) catch @panic("DB error");
        self.finishJob();
    }

    fn finishJob(_: *FindPlayerPositionJob) void {
        std.debug.print("finished finding player position\n", .{});
        var msg: buffer.buffer_message = buffer.new_message(.player_pos);
        buffer.set_progress(&msg, true, 1);
        const bd: buffer.buffer_data = .{
            .player_pos = .{},
        };
        buffer.put_data(msg, bd) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("unable to write message");
    }
};

const std = @import("std");
const config = @import("config");
const game = @import("../../game.zig");
const blecs = @import("../../blecs/blecs.zig");
const data = @import("../../data/data.zig");
const chunk_file = data.chunk_file;
const buffer = @import("../buffer.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
