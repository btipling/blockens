pub fn indexToPosition(i: i32) @Vector(4, i32) {
    // We are y up. Even are y 1, odd are y 0, because top first for consistency
    const y: i32 = if (@mod(i, 2) == 0) 1 else 0;
    // With y tackled, we split are drawing 4 chunks for each level.
    // x are odd, z are even
    const x: i32 = if (i < 4) 0 else 1;
    const z: i32 = if (i < 2 or (i >= 4 and i < 6)) 0 else 1;
    return .{ x, y, z, i };
}

pub const TerrainGenJob = struct {
    pt: *buffer.ProgressTracker,
    position: @Vector(4, i32),
    pub fn exec(self: *TerrainGenJob) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("TerrainGen");
            const tracy_zone = ztracy.ZoneNC(@src(), "TerrainGen", 0xF0_00_ff_f0);
            defer tracy_zone.End();
            self.terrainGenJob();
        } else {
            self.terrainGenJob();
        }
    }

    pub fn terrainGenJob(self: *TerrainGenJob) void {
        const data = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
        errdefer game.state.allocator.free(data);

        std.debug.print("current script:\n `{s}`\n\n", .{&game.state.ui.terrain_gen_buf});

        const i = self.position[3];
        const pos: @Vector(4, i32) = indexToPosition(i);
        @memset(data, 0xFF_FFF_00 + @as(u32, @intCast(i + 1)));

        const position: @Vector(4, f32) = .{
            @as(f32, @floatFromInt(pos[0])),
            @as(f32, @floatFromInt(pos[1])),
            @as(f32, @floatFromInt(pos[2])),
            0,
        };

        var msg: buffer.buffer_message = buffer.new_message(.terrain_gen);
        const bd: buffer.buffer_data = .{
            .terrain_gen = .{
                .data = data,
                .position = position,
            },
        };

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
        buffer.put_data(msg, bd) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("unable to write message");
    }
};

const std = @import("std");
const game = @import("../../game.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
const state = @import("../../state.zig");
const blecs = @import("../../blecs/blecs.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");
