const job_name = "SubChunkMeshJob";

pub const SubChunkMeshJob = struct {
    wp: chunk.worldPosition,
    sub_pos: chunk.subchunk.subPosition,
    chunk_data: []const u32,
    pt: *buffer.ProgressTracker,

    pub fn exec(self: *SubChunkMeshJob) void {
        if (config.use_tracy) {
            ztracy.SetThreadName(job_name);
            const tracy_zone = ztracy.ZoneNC(@src(), job_name, 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.mesh();
        } else {
            self.mesh();
        }
    }

    pub fn mesh(self: *SubChunkMeshJob) void {
        if (config.use_tracy) ztracy.Message("starting subchunk mesh");
        self.finishJob();
        if (config.use_tracy) ztracy.Message("done with sub chunk mesh job");
    }

    fn finishJob(self: *SubChunkMeshJob) void {
        const msg: buffer.buffer_message = buffer.new_message(.sub_chunk_mesh);
        const bd: buffer.buffer_data = .{
            .sub_chunk_mesh = .{
                .wp = self.wp,
                .sub_pos = self.sub_pos,
            },
        };
        self.pt.completeOne(msg, bd);
    }
};

const std = @import("std");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const config = @import("config");
const game = @import("../../game.zig");
const blecs = @import("../../blecs/blecs.zig");
const buffer = @import("../buffer.zig");
const gfx = @import("../../gfx/gfx.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
