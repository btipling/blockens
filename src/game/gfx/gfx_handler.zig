pub fn handle_incoming() void {
    thread.gfx.gfx_result_buffer.read(handle);
}

fn handle(res: thread.gfx.GfxResultBuffer.gfxResult) void {
    switch (res) {
        thread.gfx.GfxResultBuffer.gfxResult.settings_sub_chunk_draws => |d| {
            game.state.gfx.deinitSettingsDraws();
            game.state.gfx.settings_sub_chunk_draws = d;
        },
        thread.gfx.GfxResultBuffer.gfxResult.game_sub_chunk_draws => |d| {
            game.state.gfx.deinitGameDraws();
            game.state.gfx.game_sub_chunk_draws = d;
        },
    }
}

const std = @import("std");
const game = @import("../game.zig");
const thread = @import("../thread/thread.zig");
