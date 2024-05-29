const job_name = "SubChunkCullJob";

pub const SubChunkCullJob = struct {
    pub fn exec(self: *SubChunkCullJob) void {
        if (config.use_tracy) {
            ztracy.SetThreadName(job_name);
            const tracy_zone = ztracy.ZoneNC(@src(), job_name, 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.cull();
        } else {
            self.cull();
        }
    }

    pub fn cull(_: *SubChunkCullJob) void {
        const sorter = game.state.gfx.game_sub_chunks_sorter;
        if (config.use_tracy) ztracy.Message("starting sub_chunk cull");
        sorter.cullFrustum();
        if (config.use_tracy) ztracy.Message("done with sub chunk cull job");
    }
};

const std = @import("std");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const game = @import("../../game.zig");
const config = @import("config");
const buffer = @import("../buffer.zig");
const gfx = @import("../../gfx/gfx.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
