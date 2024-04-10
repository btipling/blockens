const std = @import("std");
const game = @import("../../game.zig");
const chunk = @import("../../chunk.zig");
const blecs = @import("../../blecs/blecs.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");

pub const GenerateWorldChunkJob = struct {
    wp: chunk.worldPosition,
    script: []u8,

    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("GenerateWorldChunkJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "GenerateWorldChunkJob", 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.generateWorldChunkJob();
        } else {
            self.generateWorldChunkJob();
        }
    }

    pub fn generateWorldChunkJob(self: *@This()) void {
        const chunk_data = game.state.script.evalChunkFunc(self.script) catch |err| {
            std.debug.print("Error evaluating chunk in eval chunks function: {}\n", .{err});
            return;
        };
        game.state.allocator.free(self.script);
        var msg: buffer.buffer_message = buffer.new_message(.chunk_gen);
        buffer.set_progress(&msg, true, 1);
        buffer.put_chunk_gen_data(msg, .{
            .chunk_data = chunk_data,
            .wp = self.wp,
        }) catch unreachable;
        buffer.write_message(msg) catch @panic("unable to write message");
    }
};
