const std = @import("std");
const game = @import("../game.zig");
const script = @import("../script/script.zig");
const blecs = @import("../blecs/blecs.zig");
const buffer = @import("../thread/buffer.zig");

pub const GenerateDemoChunkJob = struct {
    pub fn exec(_: *@This()) void {
        std.debug.print("GenerateDemoChunkJob: evaling current chunk buf\n", .{});
        const chunk_data = game.state.script.evalChunkFunc(game.state.ui.data.chunk_buf) catch |err| {
            std.debug.print("Error evaluating chunk function: {}\n", .{err});
            return;
        };
        buffer.
        var msg: buffer.buffer_message = buffer.new_message( .chunk_gen);
        buffer.set_progress(&msg, true, 1);
    }
};
