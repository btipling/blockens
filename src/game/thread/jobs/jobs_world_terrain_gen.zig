pub const WorldTerrainGenJob = struct {
    descriptors: std.ArrayList(*descriptor.root),
    world_id: i32,
    x: i32,
    z: i32,
    pt: *buffer.ProgressTracker,
    pub fn exec(self: *WorldTerrainGenJob) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("WorldTerrainGen");
            const tracy_zone = ztracy.ZoneNC(@src(), "WorldTerrainGen", 0xF0_00_ff_f0);
            defer tracy_zone.End();
            self.worldTerrainGenJob();
        } else {
            self.worldTerrainGenJob();
        }
    }

    pub fn worldTerrainGenJob(self: *WorldTerrainGenJob) void {
        std.debug.print("Generating world terrain in job\n", .{});
        var t_data: []u32 = undefined;
        var b_data: []u32 = undefined;

        for (self.descriptors.items) |dr| {
            //TODO: don't overwrite previous completetely chunk data after first terrain gen run.
            var position: @Vector(4, i32) = .{ self.x, 1, self.z, 0 };
            var gen: terrain_gen = .{
                .desc_root = dr,
                .position = position,
            };
            if (gen.genereate()) |res| {
                t_data = res.data;
            } else @panic("failed to generate top chunk terrain");

            position[1] = 0;
            gen = .{
                .desc_root = dr,
                .position = position,
            };
            if (gen.genereate()) |res| {
                b_data = res.data;
            } else @panic("failed to bot chunk generate terrain");
        }
        defer game.state.allocator.free(t_data);
        defer game.state.allocator.free(b_data);
        {
            const top_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
            defer game.state.allocator.free(top_chunk);
            const bottom_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
            defer game.state.allocator.free(bottom_chunk);
            var i: usize = 0;
            while (i < chunk.chunkSize) : (i += 1) {
                top_chunk[i] = @intCast(t_data[i]);
                bottom_chunk[i] = @intCast(b_data[i]);
            }
            game.state.db.saveChunkMetadata(self.world_id, self.x, 1, self.z, 0) catch @panic("db error");
            game.state.db.saveChunkMetadata(self.world_id, self.x, 0, self.z, 0) catch @panic("db error");
            data.chunk_file.saveChunkData(
                game.state.allocator,
                self.world_id,
                self.x,
                self.z,
                top_chunk,
                bottom_chunk,
            );
        }
        self.finishJob();
    }

    fn finishJob(self: *WorldTerrainGenJob) void {
        const msg: buffer.buffer_message = buffer.new_message(.world_terrain_gen);
        const bd: buffer.buffer_data = .{
            .world_terrain_gen = .{
                .world_id = self.world_id,
                .descriptors = self.descriptors,
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
const data = @import("../../data/data.zig");
const chunk = block.chunk;
const descriptor = chunk.descriptor;
const terrain_gen = @import("../../block/chunk_terrain_gen.zig");
