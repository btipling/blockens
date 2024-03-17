const std = @import("std");
const game = @import("../../game.zig");
const script = @import("../../script/script.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");

pub const GenerateDemoChunkJob = struct {
    pub fn exec(_: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("GenerateDemoChunkJob");
        }
        std.debug.print("GenerateDemoChunkJob: evaling current chunk buf\n", .{});
        const chunk_data = game.state.script.evalChunkFunc(&game.state.ui.data.chunk_buf) catch |err| {
            std.debug.print("Error evaluating chunk function: {}\n", .{err});
            return;
        };
        var msg: buffer.buffer_message = buffer.new_message(.chunk_gen);
        buffer.set_demo_chunk(&msg);
        buffer.set_progress(&msg, true, 1);
        buffer.put_chunk_gen_data(msg, .{
            .chunk_data = chunk_data,
        }) catch unreachable;
        buffer.write_message(msg) catch unreachable;
    }
};
