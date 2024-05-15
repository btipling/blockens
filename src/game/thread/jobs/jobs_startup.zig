pub const StartupJob = struct {
    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("SaveJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "SaveJob", 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.startUpJob() catch @panic("startup failed");
        } else {
            self.startUpJob() catch @panic("startup failed");
        }
    }

    pub fn startUpJob(self: *StartupJob) !void {
        std.debug.print("starting up\n", .{});
        self.primeColumns();
        _ = game.state.db.ensureState() catch |err| {
            std.log.err("Failed to ensure default world: {}\n", .{err});
            return err;
        };
        self.finishJob();
    }

    pub fn finishJob(_: *StartupJob) void {
        var msg: buffer.buffer_message = buffer.new_message(.startup);
        buffer.set_progress(&msg, true, 1);
        const bd: buffer.buffer_data = .{
            .startup = .{
                .done = true,
            },
        };
        buffer.put_data(msg, bd) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("unable to write message");
        std.debug.print("done starting up\n", .{});
    }

    pub fn primeColumns(_: StartupJob) void {
        for (0..game_config.worldChunkDims) |i| {
            const x: i32 = @as(i32, @intCast(i)) - @as(i32, @intCast(game_config.worldChunkDims / 2));
            for (0..game_config.worldChunkDims) |ii| {
                const z: i32 = @as(i32, @intCast(ii)) - @as(i32, @intCast(game_config.worldChunkDims / 2));
                chunk.column.prime(x, z);
            }
        }
    }
};

const std = @import("std");
const game = @import("../../game.zig");
const data = @import("../../data/data.zig");
const config = @import("config");
const buffer = @import("../buffer.zig");
const script = @import("../../script/script.zig");
const game_config = @import("../../config.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
