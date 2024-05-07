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
    pt: *buffer.ProgressTracker,
    position: @Vector(4, i32),
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
        // const terrain_position: @Vector(4, f32) = .{
        //     @as(f32, @floatFromInt(self.position[0])),
        //     @as(f32, @floatFromInt(self.position[1])),
        //     @as(f32, @floatFromInt(self.position[2])),
        //     0,
        // };

        const data = game.state.script.evalTerrainFunc(
            // game.state.ui.terrain_gen_seed,
            // terrain_position,
            &game.state.ui.terrain_gen_buf,
        ) catch |err| {
            std.debug.print("Error evaluating terrain gen function: {}\n", .{err});
            return;
        };
        errdefer game.state.allocator.free(data);
        std.debug.print("Generated terrain in job\n", .{});
        var ci: usize = 0;
        while (ci < chunk.chunkSize) : (ci += 1) {
            var bd: block.BlockData = block.BlockData.fromId(data[ci]);
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

        var msg: buffer.buffer_message = buffer.new_message(.terrain_gen);
        const bd: buffer.buffer_data = .{
            .terrain_gen = .{
                .data = data,
                .position = chunk_position,
            },
        };

        const done: bool, const num_started: usize, const num_done: usize = self.pt.completeOne();
        if (done) game.state.allocator.destroy(self.pt);
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

    //  noiseGen = allocator.create(znoise.FnlGenerator) catch @panic("OOM");

    //     noiseGen.* = znoise.FnlGenerator{
    //         .seed = 0,
    //         .frequency = -0.002,
    //         .noise_type = .opensimplex2,
    //         .rotation_type3 = .improve_xz_planes,
    //         .fractal_type = .fbm,
    //         .octaves = 10,
    //         .lacunarity = 1.350,
    //         .gain = 0.0,
    //         .weighted_strength = 0.0,
    //         .ping_pong_strength = 0.0,
    //         .cellular_distance_func = .euclidean,
    //         .cellular_return_type = .cellvalue,
    //         .cellular_jitter_mod = 2.31,
    //         .domain_warp_type = .basicgrid,
    //         .domain_warp_amp = 1.0,
    //     };
};

const std = @import("std");
const game = @import("../../game.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
const state = @import("../../state.zig");
const blecs = @import("../../blecs/blecs.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");
