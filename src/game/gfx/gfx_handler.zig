pub fn handle_incoming() void {
    if (config.use_tracy) {
        const tracy_zone = ztracy.ZoneNC(@src(), "GfxThreadHandleIncomingRead", 0x0F_CF_82_f0);
        defer tracy_zone.End();
        thread.gfx.gfx_result_buffer.read(handle);
        return;
    }
    thread.gfx.gfx_result_buffer.read(handle);
}

fn handle(res: thread.gfx.GfxResultBuffer.gfxResult) void {
    if (config.use_tracy) ztracy.Message("handling gfx result");
    switch (res) {
        thread.gfx.GfxResultBuffer.gfxResult.settings_sub_chunk_draws => |d| {
            if (config.use_tracy) ztracy.Message("handling gfx result: settings_sub_chunk_draws");
            game.state.gfx.settings_sub_chunk_draws = d;
        },
        thread.gfx.GfxResultBuffer.gfxResult.game_sub_chunk_draws => |d| {
            if (config.use_tracy) ztracy.Message("handling gfx result: game_sub_chunk_draws");
            game.state.gfx.game_sub_chunk_draws = d;
        },
        thread.gfx.GfxResultBuffer.gfxResult.new_ssbo => |d| {
            std.debug.print("binding ssbo in main thread: {d} at binding point {d}\n", .{ d.ssbo, d.binding_point });
            gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, d.ssbo);
            gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, d.binding_point, d.ssbo);
        },
        thread.gfx.GfxResultBuffer.gfxResult.game_sub_chunks_ready => {
            blecs.entities.screen.initGameSubChunks();
            screen_helpers.showGameScreen();
            ui_helpers.loadCharacterInWorld();
        },
    }
}

const std = @import("std");
const config = @import("config");
const ztracy = @import("ztracy");
const gl = @import("zopengl").bindings;
const game = @import("../game.zig");
const blecs = @import("../blecs/blecs.zig");
const ui_helpers = @import("../blecs/systems/ui/ui_helpers.zig");
const screen_helpers = @import("../blecs/systems/screen_helpers.zig");
const thread = @import("../thread/thread.zig");
