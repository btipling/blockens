const std = @import("std");
const game = @import("../game.zig");
const script = @import("../script/script.zig");
const blecs = @import("../blecs/blecs.zig");

pub const GenerateDemoChunkJob = struct {
    pub fn exec(_: *@This()) void {
        std.debug.print("GenerateDemoChunkJob: evaling current chunk buf\n", .{});
        const chunk_data = game.state.script.evalChunkFunc(game.state.ui.data.chunk_buf) catch |err| {
            std.debug.print("Error evaluating chunk function: {}\n", .{err});
            return;
        };
        if (game.state.ui.data.chunk_demo_data) |d| game.state.allocator.free(d);
        game.state.ui.data.chunk_demo_data = chunk_data;
        blecs.ecs.add(game.state.world, game.state.entities.screen, blecs.components.screen.NeedsDemoChunk);
    }
};
