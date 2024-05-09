pub fn indexToPosition(i: i32) @Vector(4, i32) {
    // We are y up. Even are y 1, odd are y 0, because top first for consistency
    const y: i32 = if (@mod(i, 2) == 0) 1 else 0;
    // With y tackled, we split are drawing 4 chunks for each level.
    // x are odd, z are even
    const x: i32 = if (i < 4) 0 else 1;
    const z: i32 = if (i < 2 or (i >= 4 and i < 6)) 0 else 1;
    return .{ x, y, z, i };
}

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
        const noise_type: znoise.FnlGenerator.NoiseType = switch (self.desc_root.config.noise_type) {
            .opensimplex2 => .opensimplex2,
            .opensimplex2s => .opensimplex2s,
            .cellular => .cellular,
            .perlin => .perlin,
            .value_cubic => .value_cubic,
            .value => .value,
        };
        var noiseGen = znoise.FnlGenerator{
            .seed = 0,
            .frequency = self.desc_root.config.frequency,
            .noise_type = noise_type,
            .rotation_type3 = .none,
            .fractal_type = .fbm,
            .octaves = self.desc_root.config.octaves,
            .lacunarity = 1.350,
            .gain = 0.0,
            .weighted_strength = 0.0,
            .ping_pong_strength = 0.0,
            .cellular_distance_func = .euclidean,
            .cellular_return_type = .cellvalue,
            .cellular_jitter_mod = self.desc_root.config.jitter,
            .domain_warp_type = .basicgrid,
            .domain_warp_amp = 1.0,
        };
        const chunk_x: f32 = @floatFromInt(self.position[0]);
        const chunk_z: f32 = @floatFromInt(self.position[2]);

        var data = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
        errdefer game.state.allocator.free(data);
        std.debug.print("Generating terrain in job\n", .{});
        var ci: usize = 0;
        while (ci < chunk.chunkSize) : (ci += 1) {
            const ci_pos = chunk.getPositionAtIndexV(ci);
            const n = noiseGen.noise2(
                ci_pos[0] + (chunk_x * chunk.chunkDim),
                ci_pos[2] + (chunk_z * chunk.chunkDim),
            );
            const bi = self.desc_root.node.getBlockId(
                @intFromFloat(ci_pos[1]),
                n,
            ) catch {
                std.log.err("Misconfigured lua desc resulted in invalid block id\n", .{});
                self.desc_root.debugPrint();
                game.state.allocator.free(data);
                self.finishJob(false, null, .{ 0, 0, 0, 0 });
                return;
            };
            var bd: block.BlockData = block.BlockData.fromId(bi.block_id);
            bd.setSettingsAmbient();
            data[ci] = bd.toId();
        }
        const i = self.position[3];
        const pos: @Vector(4, i32) = indexToPosition(i);
        const chunk_position: @Vector(4, f32) = .{
            @as(f32, @floatFromInt(pos[0])),
            @as(f32, @floatFromInt(pos[1])),
            @as(f32, @floatFromInt(pos[2])),
            0,
        };

        self.finishJob(true, data, chunk_position);
    }

    fn finishJob(self: *TerrainGenJob, succeeded: bool, data: ?[]u32, chunk_position: @Vector(4, f32)) void {
        var msg: buffer.buffer_message = buffer.new_message(.terrain_gen);
        const bd: buffer.buffer_data = .{
            .terrain_gen = .{
                .succeeded = succeeded,
                .data = data,
                .position = chunk_position,
            },
        };

        const done: bool, const num_started: usize, const num_done: usize = self.pt.completeOne();
        if (done) {
            self.desc_root.deinit();
            game.state.allocator.destroy(self.pt);
        }
        const ns: f16 = @floatFromInt(num_started);
        const nd: f16 = @floatFromInt(num_done);
        const pr: f16 = nd / ns;
        buffer.set_progress(
            &msg,
            done,
            pr,
        );
        buffer.put_data(msg, bd) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("unable to write message");
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
