const air: u8 = 0;
const max_trigger_depth: u8 = 3;

pub const LightingCrossChunkJob = struct {
    world_id: i32,
    x: i32,
    z: i32,
    pt: *buffer.ProgressTracker,

    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("LightingCrossChunkJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "LightingCrossChunkJob", 0x00_C0_82_f0);
            defer tracy_zone.End();
            self.lightingCrossChunkJob();
        } else {
            self.lightingCrossChunkJob();
        }
    }

    fn cData(self: @This(), x: i32, z: i32) struct { []u32, []u32 } {
        const t_block_data: []u32 = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
        const bt_block_data: []u32 = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
        {
            const top_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
            defer game.state.allocator.free(top_chunk);
            const bottom_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
            defer game.state.allocator.free(bottom_chunk);
            data.chunk_file.loadChunkData(game.state.allocator, self.world_id, x, z, top_chunk, bottom_chunk);
            var ci: usize = 0;
            while (ci < chunk.chunkSize) : (ci += 1) {
                t_block_data[ci] = @truncate(top_chunk[ci]);
                bt_block_data[ci] = @truncate(bottom_chunk[ci]);
            }
        }
        return .{ t_block_data, bt_block_data };
    }

    pub fn lightingCrossChunkJob(self: *@This()) void {
        const t_block_data: []u32, const bt_block_data: []u32 = self.cData(self.x, self.z);
        defer game.state.allocator.free(t_block_data);
        defer game.state.allocator.free(bt_block_data);
        {
            const wp = chunk.worldPosition.initFromPositionV(.{
                @floatFromInt(self.x),
                1,
                @floatFromInt(self.z),
                0,
            });
            self.fixCrossChunkLighting(wp, t_block_data, bt_block_data);
        }
        {
            const top_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
            defer game.state.allocator.free(top_chunk);
            const bottom_chunk: []u64 = game.state.allocator.alloc(u64, chunk.chunkSize) catch @panic("OOM");
            defer game.state.allocator.free(bottom_chunk);
            var i: usize = 0;
            while (i < chunk.chunkSize) : (i += 1) {
                top_chunk[i] = @intCast(t_block_data[i]);
                bottom_chunk[i] = @intCast(bt_block_data[i]);
            }
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

    fn finishJob(self: *LightingCrossChunkJob) void {
        var msg: buffer.buffer_message = buffer.new_message(.lighting_cross_chunk);
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
        const bd: buffer.buffer_data = .{
            .lighting = .{
                .world_id = self.world_id,
                .x = self.x,
                .z = self.z,
            },
        };
        buffer.put_data(msg, bd) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("unable to write message");
    }

    fn lightFallDimensional(
        self: *LightingCrossChunkJob,
        c_data: []u32,
        ci: usize,
        ll: block.BlockLighingLevel,
        s: block.BlockSurface,
    ) void {
        var bd: block.BlockData = block.BlockData.fromId(c_data[ci]);
        if (bd.block_id == air) {
            const bd_ll = bd.getFullAmbiance();
            if (ll.isBrighterThan(bd_ll) and ll != bd_ll) {
                bd.setFullAmbiance(ll.getNextDarker());
                c_data[ci] = bd.toId();
                self.lightFall(c_data, ci, bd.getFullAmbiance());
            }
            return;
        }
        const s_b = bd.getSurfaceAmbience(s);
        if (ll.isBrighterThan(s_b) and ll != s_b) {
            bd.setAmbient(s, ll);
            c_data[ci] = bd.toId();
        }
    }

    fn lightFall(self: *LightingCrossChunkJob, c_data: []u32, ci: usize, ll: block.BlockLighingLevel) void {
        if (ll == .none) return;
        const pos = chunk.getPositionAtIndexV(ci);
        x_pos: {
            const x = pos[0] + 1;
            if (x >= chunk.chunkDim) break :x_pos;
            const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
            if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
            self.lightFallDimensional(c_data, c_ci, ll, .x_neg);
        }
        x_neg: {
            const x = pos[0] - 1;
            if (x < 0) break :x_neg;
            const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
            self.lightFallDimensional(c_data, c_ci, ll, .x_pos);
        }
        y_pos: {
            const y = pos[1] + 1;
            if (y >= chunk.chunkDim) break :y_pos;
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
            if (c_ci >= chunk.chunkSize) std.debug.panic("invalid y_pos >= chunk size", .{});
            self.lightFallDimensional(c_data, c_ci, ll, .y_neg);
        }
        y_neg: {
            const y = pos[1] - 1;
            if (y < 0) break :y_neg;
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
            self.lightFallDimensional(c_data, c_ci, ll, .y_pos);
        }
        z_pos: {
            const z = pos[2] + 1;
            if (z >= chunk.chunkDim) break :z_pos;
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
            if (c_ci >= chunk.chunkSize) std.debug.panic("invalid z_pos >= chunk size", .{});
            self.lightFallDimensional(c_data, c_ci, ll, .z_neg);
        }
        z_neg: {
            const z = pos[2] - 1;
            if (z < 0) break :z_neg;
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
            self.lightFallDimensional(c_data, c_ci, ll, .z_pos);
        }
    }

    fn lightCrossing(
        self: *LightingCrossChunkJob,
        this_data: []u32,
        this_ci: usize,
        this_bd: *block.BlockData,
        other_bd: block.BlockData,
        surface_facing_other_chunk: block.BlockSurface,
    ) void {
        // Two blocks facing each other - no light adjustment
        if (this_bd.block_id != air and other_bd.block_id != air) return;
        // Brighten the air between the two if need be
        if (this_bd.block_id == air and other_bd.block_id == air) {
            const am = this_bd.getFullAmbiance();
            const c_am = other_bd.getFullAmbiance();
            if (am == c_am) return; // isBrighterThan returns true when values are equal
            if (am.isBrighterThan(c_am) and c_am == am.getNextDarker()) return;
            if (c_am.isBrighterThan(am) and am == c_am.getNextDarker()) return;
            // Only working on this chunk, other chunk will update from this chunk separately.
            if (am.isBrighterThan(c_am)) return;
            this_bd.setFullAmbiance(c_am.getNextDarker());
            this_data[this_ci] = this_bd.toId();
            self.lightFall(this_data, this_ci, this_bd.getFullAmbiance());
            return;
        }
        if (this_bd.block_id == air) return; // The other chunk will update itself.
        if (other_bd.block_id == air) {
            const other_ll = other_bd.getFullAmbiance();
            this_bd.setAmbient(surface_facing_other_chunk, other_ll);
            this_data[this_ci] = this_bd.toId();
            return;
        }
    }

    fn fixCrossChunkLighting(self: *LightingCrossChunkJob, wp: chunk.worldPosition, top_chunk: []u32, bot_chunk: []u32) void {
        {
            const zp_p = wp.getZPosWP().vecFromWorldPosition();
            const zp_top_chunk: []u32, const zp_bottom_chunk: []u32 = self.cData(
                @intFromFloat(zp_p[0]),
                @intFromFloat(zp_p[2]),
            );
            defer game.state.allocator.free(zp_top_chunk);
            defer game.state.allocator.free(zp_bottom_chunk);
            // compare planes 63 z of c and 0 z of zp_c
            {
                const c_z: f32 = 63;
                const zp_z: f32 = 0;
                var y: f32 = 63;
                while (y >= 0) : (y -= 1) {
                    var x: f32 = 0;
                    while (x < chunk.chunkDim) : (x += 1) {
                        const c_i = chunk.getIndexFromPositionV(.{ x, y, c_z, 0 });
                        var c_bd: block.BlockData = block.BlockData.fromId(top_chunk[c_i]);
                        const zp_i = chunk.getIndexFromPositionV(.{ x, y, zp_z, 0 });
                        const zp_bd: block.BlockData = block.BlockData.fromId(zp_top_chunk[zp_i]);
                        self.lightCrossing(top_chunk, c_i, &c_bd, zp_bd, .z_pos);
                    }
                }
            }
            {
                const c_z: f32 = 63;
                const zp_z: f32 = 0;
                var y: f32 = 63;
                while (y >= 0) : (y -= 1) {
                    var x: f32 = 0;
                    while (x < chunk.chunkDim) : (x += 1) {
                        const c_i = chunk.getIndexFromPositionV(.{ x, y, c_z, 0 });
                        var c_bd: block.BlockData = block.BlockData.fromId(bot_chunk[c_i]);
                        const zp_i = chunk.getIndexFromPositionV(.{ x, y, zp_z, 0 });
                        const zp_bd: block.BlockData = block.BlockData.fromId(zp_bottom_chunk[zp_i]);
                        self.lightCrossing(bot_chunk, c_i, &c_bd, zp_bd, .z_pos);
                    }
                }
            }
        }
        {
            const zn_p = wp.getZNegWP().vecFromWorldPosition();
            const zn_top_chunk: []u32, const zn_bottom_chunk: []u32 = self.cData(
                @intFromFloat(zn_p[0]),
                @intFromFloat(zn_p[2]),
            );
            defer game.state.allocator.free(zn_top_chunk);
            defer game.state.allocator.free(zn_bottom_chunk);
            // compare planes 0 z of c and 63 z of b_c
            {
                const c_z: f32 = 0;
                const c_zn: f32 = 63;
                var y: f32 = 63;
                while (y >= 0) : (y -= 1) {
                    var x: f32 = 0;
                    while (x < chunk.chunkDim) : (x += 1) {
                        const c_i = chunk.getIndexFromPositionV(.{ x, y, c_z, 0 });
                        var c_bd: block.BlockData = block.BlockData.fromId(top_chunk[c_i]);
                        const zn_i = chunk.getIndexFromPositionV(.{ x, y, c_zn, 0 });
                        const zn_bd: block.BlockData = block.BlockData.fromId(zn_top_chunk[zn_i]);
                        self.lightCrossing(top_chunk, c_i, &c_bd, zn_bd, .z_neg);
                    }
                }
            }
            {
                const c_z: f32 = 0;
                const c_zn: f32 = 63;
                var y: f32 = 63;
                while (y >= 0) : (y -= 1) {
                    var x: f32 = 0;
                    while (x < chunk.chunkDim) : (x += 1) {
                        const c_i = chunk.getIndexFromPositionV(.{ x, y, c_z, 0 });
                        var c_bd: block.BlockData = block.BlockData.fromId(bot_chunk[c_i]);
                        const zn_i = chunk.getIndexFromPositionV(.{ x, y, c_zn, 0 });
                        const zn_bd: block.BlockData = block.BlockData.fromId(zn_bottom_chunk[zn_i]);
                        self.lightCrossing(bot_chunk, c_i, &c_bd, zn_bd, .z_neg);
                    }
                }
            }
        }
        {
            const xp_p = wp.getXPosWP().vecFromWorldPosition();
            const xp_top_chunk: []u32, const xp_bottom_chunk: []u32 = self.cData(
                @intFromFloat(xp_p[0]),
                @intFromFloat(xp_p[2]),
            );
            defer game.state.allocator.free(xp_top_chunk);
            defer game.state.allocator.free(xp_bottom_chunk);
            // compare planes 63 x of c and 0 x of xp_c
            {
                const c_x: f32 = 63;
                const xp_x: f32 = 0;
                var y: f32 = 63;
                while (y >= 0) : (y -= 1) {
                    var z: f32 = 0;
                    while (z < chunk.chunkDim) : (z += 1) {
                        const c_i = chunk.getIndexFromPositionV(.{ c_x, y, z, 0 });
                        var c_bd: block.BlockData = block.BlockData.fromId(top_chunk[c_i]);
                        const xp_i = chunk.getIndexFromPositionV(.{ xp_x, y, z, 0 });
                        const xp_bd: block.BlockData = block.BlockData.fromId(xp_top_chunk[xp_i]);
                        self.lightCrossing(top_chunk, c_i, &c_bd, xp_bd, .x_pos);
                    }
                }
            }
            {
                const c_x: f32 = 63;
                const xp_x: f32 = 0;
                var y: f32 = 63;
                while (y >= 0) : (y -= 1) {
                    var z: f32 = 0;
                    while (z < chunk.chunkDim) : (z += 1) {
                        const c_i = chunk.getIndexFromPositionV(.{ c_x, y, z, 0 });
                        var c_bd: block.BlockData = block.BlockData.fromId(bot_chunk[c_i]);
                        const xp_i = chunk.getIndexFromPositionV(.{ xp_x, y, z, 0 });
                        const xp_bd: block.BlockData = block.BlockData.fromId(xp_bottom_chunk[xp_i]);
                        self.lightCrossing(bot_chunk, c_i, &c_bd, xp_bd, .x_pos);
                    }
                }
            }
        }
        {
            const xn_p = wp.getXNegWP().vecFromWorldPosition();
            const xn_top_chunk: []u32, const xn_bottom_chunk: []u32 = self.cData(
                @intFromFloat(xn_p[0]),
                @intFromFloat(xn_p[2]),
            );
            defer game.state.allocator.free(xn_top_chunk);
            defer game.state.allocator.free(xn_bottom_chunk);
            // compare planes 0 x of c and 63 x of r_c
            {
                const c_x: f32 = 0;
                const xn_x: f32 = 63;
                var y: f32 = 63;
                while (y >= 0) : (y -= 1) {
                    var z: f32 = 0;
                    while (z < chunk.chunkDim) : (z += 1) {
                        const c_i = chunk.getIndexFromPositionV(.{ c_x, y, z, 0 });
                        var c_bd: block.BlockData = block.BlockData.fromId(top_chunk[c_i]);
                        const xn_i = chunk.getIndexFromPositionV(.{ xn_x, y, z, 0 });
                        const xn_bd: block.BlockData = block.BlockData.fromId(xn_top_chunk[xn_i]);
                        self.lightCrossing(top_chunk, c_i, &c_bd, xn_bd, .x_neg);
                    }
                }
            }
            {
                const c_x: f32 = 0;
                const xn_x: f32 = 63;
                var y: f32 = 63;
                while (y >= 0) : (y -= 1) {
                    var z: f32 = 0;
                    while (z < chunk.chunkDim) : (z += 1) {
                        const c_i = chunk.getIndexFromPositionV(.{ c_x, y, z, 0 });
                        var c_bd: block.BlockData = block.BlockData.fromId(bot_chunk[c_i]);
                        const xn_i = chunk.getIndexFromPositionV(.{ xn_x, y, z, 0 });
                        const xn_bd: block.BlockData = block.BlockData.fromId(xn_bottom_chunk[xn_i]);
                        self.lightCrossing(bot_chunk, c_i, &c_bd, xn_bd, .x_neg);
                    }
                }
            }
        }
    }
};

const std = @import("std");
const game = @import("../../game.zig");
const data = @import("../../data/data.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
