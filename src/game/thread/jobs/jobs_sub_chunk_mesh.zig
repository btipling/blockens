const job_name = "SubChunkMeshJob";

pub const SubChunkMeshJob = struct {
    wp: chunk.worldPosition,
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
        var sub_chunks: [64]*chunk.sub_chunk = undefined;
        var i: usize = 0;
        var x: usize = 0;
        while (x < 4) : (x += 1) {
            var z: usize = 0;
            while (z < 4) : (z += 1) {
                var y: usize = 0;
                while (y < 4) : (y += 1) {
                    const sub_pos: @Vector(4, f32) = .{
                        @floatFromInt(x),
                        @floatFromInt(y),
                        @floatFromInt(z),
                        0,
                    };
                    const chunker = chunk.sub_chunk.chunker.init(
                        chunk_data,
                        sub_pos,
                        gfx.mesh.voxel_positions,
                        gfx.mesh.cube_indices,
                        gfx.mesh.voxel_normals,
                    );
                    const sc = chunk.sub_chunk.init(
                        game.state.allocator,
                        self.wp,
                        sub_pos,
                        chunker,
                    ) catch @panic("OOM");
                    sub_chunks[i] = sc;
                    i += 1;
                }
            }
        }
        self.finishJob(sub_chunks);
        if (config.use_tracy) ztracy.Message("done with sub chunk mesh job");
    }

    fn finishJob(self: *SubChunkMeshJob, sub_chunks: [64]*chunk.sub_chunk) void {
        const msg: buffer.buffer_message = buffer.new_message(.sub_chunk_mesh);
        const bd: buffer.buffer_data = .{
            .sub_chunk_mesh = .{
                .sub_chunks = sub_chunks,
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
const buffer = @import("../buffer.zig");
const gfx = @import("../../gfx/gfx.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
