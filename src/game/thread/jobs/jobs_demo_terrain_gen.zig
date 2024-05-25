pub const DemoTerrainGenJob = struct {
    desc_root: *descriptor.root,
    sub_chunks: bool,
    position: @Vector(4, i32),
    pt: *buffer.ProgressTracker,
    pub fn exec(self: *DemoTerrainGenJob) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("DemoTerrainGen");
            const tracy_zone = ztracy.ZoneNC(@src(), "DemoTerrainGen", 0xF0_00_ff_f0);
            defer tracy_zone.End();
            self.demoTerrainGenJob();
        } else {
            self.demoTerrainGenJob();
        }
    }

    pub fn demoTerrainGenJob(self: *DemoTerrainGenJob) void {
        std.debug.print("Generating terrain in job\n", .{});
        var gen: terrain_gen = .{
            .desc_root = self.desc_root,
            .position = self.position,
        };
        if (gen.genereate()) |res| {
            self.finishJob(true, res.data, res.position);
            return;
        }
        self.finishJob(false, null, .{ 0, 0, 0, 0 });
    }

    fn finishJob(self: *DemoTerrainGenJob, succeeded: bool, data: ?[]u32, chunk_position: @Vector(4, f32)) void {
        const msg: buffer.buffer_message = buffer.new_message(.demo_terrain_gen);
        const bd: buffer.buffer_data = .{
            .demo_terrain_gen = .{
                .succeeded = succeeded,
                .data = data,
                .position = chunk_position,
                .desc_root = self.desc_root,
                .sub_chunks = self.sub_chunks,
            },
        };
        self.pt.completeOne(msg, bd);
    }
};

const std = @import("std");
const znoise = @import("znoise");
const game = @import("../../game.zig");
const state = @import("../../state.zig");
const blecs = @import("../../blecs/blecs.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
const descriptor = chunk.descriptor;
const terrain_gen = @import("../../block/chunk_terrain_gen.zig");
