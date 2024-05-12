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
        const noise_map = self.generateNoiseMap();
        const chunk_y: f32 = @floatFromInt(self.position[1]);
        var data = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
        errdefer game.state.allocator.free(data);
        std.debug.print("Generating terrain in job\n", .{});
        @memset(data, 0);
        var x: usize = 0;
        while (x < chunk.chunkDim) : (x += 1) {
            var z: usize = 0;
            while (z < chunk.chunkDim) : (z += 1) {
                var y: usize = chunk.chunkDim - 1;
                var depth: usize = 0;
                while (true) : (y -= 1) {
                    const n = noise_map[x][z];
                    var column_y = y;
                    if (chunk_y > 0) column_y += chunk.chunkDim;
                    const result = self.desc_root.node.getBlockIdWithDepth(column_y, n, depth) catch {
                        std.log.err("Misconfigured lua desc resulted in invalid block id\n", .{});
                        self.desc_root.debugPrint();
                        game.state.allocator.free(data);
                        self.finishJob(false, null, .{ 0, 0, 0, 0 });
                        return;
                    };
                    if (result.column_hit) depth += 1;
                    var bd: block.BlockData = block.BlockData.fromId(result.block.block_id);
                    bd.setSettingsAmbient();
                    const ci = chunk.getIndexFromXYZ(x, y, z);
                    data[ci] = bd.toId();
                    if (y == 0) break;
                }
            }
        }
        // self.desc_root.debugPrint();
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

    pub fn generateNoiseMap(self: *TerrainGenJob) [chunk.chunkDim][chunk.chunkDim]f32 {
        var map: [chunk.chunkDim][chunk.chunkDim]f32 = undefined;
        const noise_type: znoise.FnlGenerator.NoiseType = switch (self.desc_root.config.noise_type) {
            .opensimplex2 => .opensimplex2,
            .opensimplex2s => .opensimplex2s,
            .cellular => .cellular,
            .perlin => .perlin,
            .value_cubic => .value_cubic,
            .value => .value,
        };

        const fractal_type: znoise.FnlGenerator.FractalType = switch (self.desc_root.config.fractal_type) {
            .none => .none,
            .fbm => .fbm,
            .ridged => .ridged,
            .pingpong => .pingpong,
            .domain_warp_progressive => .domain_warp_progressive,
            .domain_warp_independent => .domain_warp_independent,
        };

        const cell_dist_func: znoise.FnlGenerator.CellularDistanceFunc = switch (self.desc_root.config.cellularDistanceFunc) {
            .euclidean => .euclidean,
            .euclideansq => .euclideansq,
            .manhattan => .manhattan,
            .hybrid => .hybrid,
        };

        const cell_return_type: znoise.FnlGenerator.CellularReturnType = switch (self.desc_root.config.cellularReturnType) {
            .cellvalue => .cellvalue,
            .distance => .distance,
            .distance2 => .distance2,
            .distance2add => .distance2add,
            .distance2sub => .distance2sub,
            .distance2mul => .distance2mul,
            .distance2div => .distance2div,
        };

        var noiseGen = znoise.FnlGenerator{
            .seed = game.state.ui.terrain_gen_seed,
            .frequency = self.desc_root.config.frequency,
            .noise_type = noise_type,
            .rotation_type3 = .none,
            .fractal_type = fractal_type,
            .octaves = self.desc_root.config.octaves,
            .lacunarity = self.desc_root.config.lacunarity,
            .gain = self.desc_root.config.gain,
            .weighted_strength = self.desc_root.config.weighted_strength,
            .ping_pong_strength = self.desc_root.config.ping_pong_strength,
            .cellular_distance_func = cell_dist_func,
            .cellular_return_type = cell_return_type,
            .cellular_jitter_mod = self.desc_root.config.jitter,
            .domain_warp_type = .basicgrid,
            .domain_warp_amp = 1.0,
        };
        const chunk_x: f32 = @floatFromInt(self.position[0]);
        const chunk_z: f32 = @floatFromInt(self.position[2]);

        var ci: usize = 0;
        while (ci < chunk.chunkSize) : (ci += 1) {
            const ci_pos = chunk.getPositionAtIndexV(ci);
            const x: usize = @intFromFloat(ci_pos[0]);
            const z: usize = @intFromFloat(ci_pos[2]);
            const n = noiseGen.noise2(
                ci_pos[0] + (chunk_x * chunk.chunkDim),
                ci_pos[2] + (chunk_z * chunk.chunkDim),
            );
            map[x][z] = n;
        }
        return map;
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
