pub const GenerateSmallChunkJob = struct {
    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("GenerateSmallChunkJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "GenerateSmallChunkJob", 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.generateSmallChunkJob();
        } else {
            self.generateSmallChunkJob();
        }
    }

    pub fn generateSmallChunkJob(_: *GenerateSmallChunkJob) void {
        const chunk_data = game.state.script.evalChunkFunc(&game.state.ui.chunk_buf) catch |err| {
            std.debug.print("Error evaluating chunk in eval chunks function: {}\n", .{err});
            return;
        };
        errdefer game.state.allocator.free(chunk_data);
        var msg: buffer.buffer_message = buffer.new_message(.small_chunk_gen);
        buffer.set_progress(&msg, true, 1);
        const pos: @Vector(4, f32) = .{ 0, 0, 0, 0 };
        const bd: buffer.buffer_data = .{
            .small_chunk_gen = .{
                .wp = chunk.worldPosition.initFromPositionV(pos),
                .chunk_data = chunk_data,
            },
        };
        buffer.put_data(msg, bd) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("unable to write message");
    }
};

const std = @import("std");
const game = @import("../../game.zig");
const blecs = @import("../../blecs/blecs.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
