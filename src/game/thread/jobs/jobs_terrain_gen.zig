pub const TerrainGenJob = struct {
    desc_root: *descriptor.root,
    position: @Vector(4, i32),
    pt: *buffer.ProgressTracker,
    pub fn exec(self: *TerrainGenJob) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("TerrainGen");
            const tracy_zone = ztracy.ZoneNC(@src(), "TerrainGen", 0xF0_00_ff_f0);
            defer tracy_zone.End();
            self.terrainGenJob();
        } else {
            self.terrainGenJob();
        }
    }

    pub fn terrainGenJob(self: *TerrainGenJob) void {
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

    fn finishJob(self: *TerrainGenJob, succeeded: bool, data: ?[]u32, chunk_position: @Vector(4, f32)) void {
        const msg: buffer.buffer_message = buffer.new_message(.terrain_gen);
        const bd: buffer.buffer_data = .{
            .terrain_gen = .{
                .succeeded = succeeded,
                .data = data,
                .position = chunk_position,
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
