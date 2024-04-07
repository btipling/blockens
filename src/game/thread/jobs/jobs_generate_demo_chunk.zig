const std = @import("std");
const game = @import("../../game.zig");
const script = @import("../../script/script.zig");
const buffer = @import("../buffer.zig");
const chunk = @import("../../chunk.zig");
const block = @import("../../block.zig");
const config = @import("config");

pub const GenerateDemoChunkJob = struct {
    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("GenerateDemoChunkJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "GenerateDemoChunkJob", 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.generateDemoChunkJob();
        } else {
            self.generateDemoChunkJob();
        }
    }

    pub fn generateDemoChunkJob(_: *@This()) void {
        std.debug.print("GenerateDemoChunkJob: evaling current chunk buf\n", .{});
        var chunk_data = game.state.script.evalChunkFunc(&game.state.ui.data.chunk_buf) catch |err| {
            std.debug.print("Error evaluating chunk function: {}\n", .{err});
            return;
        };
        var i: usize = 0;
        while (i < chunk.chunkSize) : (i += 1) {
            var bd: block.BlockData = block.BlockData.fromId(chunk_data[i]);
            bd.setSettingsAmbient();
            chunk_data[i] = bd.toId();
        }
        var msg: buffer.buffer_message = buffer.new_message(.chunk_gen);
        buffer.set_demo_chunk(&msg);
        buffer.set_progress(&msg, true, 1);
        buffer.put_chunk_gen_data(msg, .{
            .chunk_data = chunk_data,
        }) catch unreachable;
        buffer.write_message(msg) catch unreachable;
    }
};
