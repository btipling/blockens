const job_name = "SubChunkBuilderJob";

pub const SubChunkBuilderJob = struct {
    sorter: *chunk.sub_chunk.sorter,
    is_terrain: bool,
    is_settings: bool,

    pub fn exec(self: *SubChunkBuilderJob) void {
        if (config.use_tracy) {
            ztracy.SetThreadName(job_name);
            const tracy_zone = ztracy.ZoneNC(@src(), job_name, 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.build();
        } else {
            self.build();
        }
    }

    pub fn build(self: *SubChunkBuilderJob) void {
        if (config.use_tracy) ztracy.Message("starting sub_chunk build");
        self.sorter.buildMeshData();
        self.sorter.sort(.{ 0, 0, 0, 0 });
        std.debug.print("sorter stuff: {d}\n", .{self.sorter.num_indices});
        self.finishJob();
        if (config.use_tracy) ztracy.Message("done with sub chunk build job");
    }

    fn finishJob(self: *SubChunkBuilderJob) void {
        var msg: buffer.buffer_message = buffer.new_message(.sub_chunk_build);
        buffer.set_demo_chunk(&msg);
        buffer.set_progress(&msg, true, 1);
        const bd: buffer.buffer_data = .{
            .sub_chunk_build = .{
                .sorter = self.sorter,
                .is_terrain = self.is_terrain,
                .is_settings = self.is_settings,
            },
        };
        buffer.put_data(msg, bd) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("unable to write message");
    }
};

const std = @import("std");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const config = @import("config");
const buffer = @import("../buffer.zig");
const gfx = @import("../../gfx/gfx.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
