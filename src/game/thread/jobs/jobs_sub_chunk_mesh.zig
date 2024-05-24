const job_name = "SubChunkMeshJob";

pub const SubChunkMeshJob = struct {
    wp: chunk.worldPosition,
    sub_pos: chunk.sub_chunk.subPosition,
    chunk_data: []const u32,
    is_terrain: bool,
    is_settings: bool,
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
        if (config.use_tracy) ztracy.Message("starting sub_chunk mesh");
        const chunk_data = self.chunk_data;
        const chunker = chunk.sub_chunk.chunker.init(
            chunk_data,
            self.sub_pos,
            gfx.mesh.cube_positions,
            gfx.mesh.cube_indices,
            gfx.mesh.cube_normals,
        );
        const sc = chunk.sub_chunk.init(
            game.state.allocator,
            self.wp,
            self.sub_pos,
            chunker,
        ) catch @panic("OOM");
        self.finishJob(sc);
        if (config.use_tracy) ztracy.Message("done with sub chunk mesh job");
    }

    fn finishJob(self: *SubChunkMeshJob, sc: *chunk.sub_chunk) void {
        const msg: buffer.buffer_message = buffer.new_message(.sub_chunk_mesh);
        const bd: buffer.buffer_data = .{
            .sub_chunk_mesh = .{
                .sub_chunk = sc,
                .is_terrain = self.is_terrain,
                .is_settings = self.is_settings,
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
