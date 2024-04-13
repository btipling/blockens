const air: u8 = 0;
const max_trigger_depth: u8 = 3;

// To use when there is no chunk, just assume fully lit.
var fully_lit_chunk: [chunk.chunkSize]u32 = [_]u32{0xFF_FFF_00} ** chunk.chunkSize;

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

    pub fn lightingCrossChunkJob(self: *@This()) void {
        var t_c: data.chunkData = .{};
        game.state.db.loadChunkData(self.world_id, self.x, 1, self.z, &t_c) catch {
            t_c.voxels = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
            @memcpy(t_c.voxels, &fully_lit_chunk);
        };
        defer game.state.allocator.free(t_c.voxels);
        var b_c: data.chunkData = .{};
        game.state.db.loadChunkData(self.world_id, self.x, 0, self.z, &b_c) catch {
            b_c.voxels = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
            @memcpy(b_c.voxels, &fully_lit_chunk);
        };
        defer game.state.allocator.free(b_c.voxels);
        const t_block_data: []u32 = t_c.voxels;
        const bt_block_data: []u32 = b_c.voxels;
        {
            const wp = chunk.worldPosition.initFromPositionV(.{
                @floatFromInt(self.x),
                1,
                @floatFromInt(self.z),
                0,
            });
            self.fixCrossChunkLighting(wp, t_block_data);
        }
        {
            const wp = chunk.worldPosition.initFromPositionV(.{
                @floatFromInt(self.x),
                0,
                @floatFromInt(self.z),
                0,
            });
            self.fixCrossChunkLighting(wp, bt_block_data);
        }
        {
            {
                game.state.db.updateChunkData(
                    t_c.id,
                    t_c.scriptId,
                    t_block_data,
                ) catch @panic("failed to save top chunk data after lighting");
            }
            {
                game.state.db.updateChunkData(
                    b_c.id,
                    b_c.scriptId,
                    bt_block_data,
                ) catch @panic("failed to save bottom chunk data after lighting");
            }
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
            self.lightFallDimensional(c_data, c_ci, ll, .left);
        }
        x_neg: {
            const x = pos[0] - 1;
            if (x < 0) break :x_neg;
            const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
            self.lightFallDimensional(c_data, c_ci, ll, .right);
        }
        y_pos: {
            const y = pos[1] + 1;
            if (y >= chunk.chunkDim) break :y_pos;
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
            if (c_ci >= chunk.chunkSize) std.debug.panic("invalid y_pos >= chunk size", .{});
            self.lightFallDimensional(c_data, c_ci, ll, .bottom);
        }
        y_neg: {
            const y = pos[1] - 1;
            if (y < 0) break :y_neg;
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
            self.lightFallDimensional(c_data, c_ci, ll, .top);
        }
        z_pos: {
            const z = pos[2] + 1;
            if (z >= chunk.chunkDim) break :z_pos;
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
            if (c_ci >= chunk.chunkSize) std.debug.panic("invalid z_pos >= chunk size", .{});
            self.lightFallDimensional(c_data, c_ci, ll, .front);
        }
        z_neg: {
            const z = pos[2] - 1;
            if (z < 0) break :z_neg;
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
            self.lightFallDimensional(c_data, c_ci, ll, .back);
        }
    }

    fn lightCrossing(
        self: *LightingCrossChunkJob,
        c_data: []u32,
        ci: usize,
        bd: *block.BlockData,
        c_bd: block.BlockData,
        s: block.BlockSurface,
    ) void {
        // Two blocks facing each other - no light adjustment
        if (bd.block_id != air and c_bd.block_id != air) return;
        // Brighten the air between the two if need be
        if (bd.block_id == air and c_bd.block_id == air) {
            const am = bd.getFullAmbiance();
            const c_am = c_bd.getFullAmbiance();
            if (am == c_am) return; // isBrighterThan returns true when values are equal
            if (am.isBrighterThan(c_am) and c_am == am.getNextDarker()) return;
            if (c_am.isBrighterThan(am) and am == c_am.getNextDarker()) return;
            // Only working on this chunk, other chunk will update from this chunk separately.
            if (am.isBrighterThan(c_am)) return;
            bd.setFullAmbiance(c_am.getNextDarker());
            c_data[ci] = bd.toId();
            self.lightFall(c_data, ci, bd.getFullAmbiance());
            return;
        }
        if (bd.block_id == air) return; // The other chunk will update itself.
        if (c_bd.block_id == air) {
            const c_am = c_bd.getFullAmbiance();
            const bd_sam = bd.getSurfaceAmbience(s);
            if (c_am == bd_sam) return;
            if (!c_am.isBrighterThan(bd_sam)) return;
            bd.setAmbient(s, c_am);
            c_data[ci] = bd.toId();
            return;
        }
    }

    fn fixCrossChunkLighting(self: *LightingCrossChunkJob, wp: chunk.worldPosition, c_data: []u32) void {
        {
            const f_p = wp.getFrontWP().vecFromWorldPosition();
            var f_c: data.chunkData = .{};
            game.state.db.loadChunkData(
                self.world_id,
                @intFromFloat(f_p[0]),
                @intFromFloat(f_p[1]),
                @intFromFloat(f_p[2]),
                &f_c,
            ) catch {
                f_c.voxels = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
                @memcpy(f_c.voxels, &fully_lit_chunk);
            };
            defer game.state.allocator.free(f_c.voxels);
            const f_data: []u32 = f_c.voxels;
            // compare planes 63 z of c and 0 z of f_c
            const c_z: f32 = 63;
            const f_z: f32 = 0;
            var y: f32 = 63;
            while (y >= 0) : (y -= 1) {
                var x: f32 = 0;
                while (x < chunk.chunkDim) : (x += 1) {
                    const c_i = chunk.getIndexFromPositionV(.{ x, y, c_z, 0 });
                    var c_bd: block.BlockData = block.BlockData.fromId(c_data[c_i]);
                    const f_i = chunk.getIndexFromPositionV(.{ x, y, f_z, 0 });
                    const f_bd: block.BlockData = block.BlockData.fromId(f_data[f_i]);
                    self.lightCrossing(c_data, c_i, &c_bd, f_bd, .back);
                }
            }
        }
        {
            const b_p = wp.getBackWP().vecFromWorldPosition();
            var b_c: data.chunkData = .{};
            game.state.db.loadChunkData(
                self.world_id,
                @intFromFloat(b_p[0]),
                @intFromFloat(b_p[1]),
                @intFromFloat(b_p[2]),
                &b_c,
            ) catch {
                b_c.voxels = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
                @memcpy(b_c.voxels, &fully_lit_chunk);
            };
            defer game.state.allocator.free(b_c.voxels);
            const b_data: []u32 = b_c.voxels;
            // compare planes 0 z of c and 63 z of b_c
            const c_z: f32 = 0;
            const b_z: f32 = 63;
            var y: f32 = 63;
            while (y >= 0) : (y -= 1) {
                var x: f32 = 0;
                while (x < chunk.chunkDim) : (x += 1) {
                    const c_i = chunk.getIndexFromPositionV(.{ x, y, c_z, 0 });
                    var c_bd: block.BlockData = block.BlockData.fromId(c_data[c_i]);
                    const b_i = chunk.getIndexFromPositionV(.{ x, y, b_z, 0 });
                    const b_bd: block.BlockData = block.BlockData.fromId(b_data[b_i]);
                    self.lightCrossing(c_data, c_i, &c_bd, b_bd, .front);
                }
            }
        }
        {
            const l_p = wp.getLeftWP().vecFromWorldPosition();
            var l_c: data.chunkData = .{};
            game.state.db.loadChunkData(
                self.world_id,
                @intFromFloat(l_p[0]),
                @intFromFloat(l_p[1]),
                @intFromFloat(l_p[2]),
                &l_c,
            ) catch {
                l_c.voxels = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
                @memcpy(l_c.voxels, &fully_lit_chunk);
            };
            defer game.state.allocator.free(l_c.voxels);
            const l_data: []u32 = l_c.voxels;
            // compare planes 63 x of c and 0 x of l_c
            const c_x: f32 = 63;
            const l_x: f32 = 0;
            var y: f32 = 63;
            while (y >= 0) : (y -= 1) {
                var z: f32 = 0;
                while (z < chunk.chunkDim) : (z += 1) {
                    const c_i = chunk.getIndexFromPositionV(.{ c_x, y, z, 0 });
                    var c_bd: block.BlockData = block.BlockData.fromId(c_data[c_i]);
                    const l_i = chunk.getIndexFromPositionV(.{ l_x, y, z, 0 });
                    const l_bd: block.BlockData = block.BlockData.fromId(l_data[l_i]);
                    self.lightCrossing(c_data, c_i, &c_bd, l_bd, .right);
                }
            }
        }
        {
            const r_p = wp.getRightWP().vecFromWorldPosition();
            var r_c: data.chunkData = .{};
            game.state.db.loadChunkData(
                self.world_id,
                @intFromFloat(r_p[0]),
                @intFromFloat(r_p[1]),
                @intFromFloat(r_p[2]),
                &r_c,
            ) catch {
                r_c.voxels = game.state.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
                @memcpy(r_c.voxels, &fully_lit_chunk);
            };
            defer game.state.allocator.free(r_c.voxels);
            const r_data: []u32 = r_c.voxels;
            // compare planes 0 x of c and 63 x of r_c
            const c_x: f32 = 0;
            const r_x: f32 = 63;
            var y: f32 = 63;
            while (y >= 0) : (y -= 1) {
                var z: f32 = 0;
                while (z < chunk.chunkDim) : (z += 1) {
                    const c_i = chunk.getIndexFromPositionV(.{ c_x, y, z, 0 });
                    var c_bd: block.BlockData = block.BlockData.fromId(c_data[c_i]);
                    const r_i = chunk.getIndexFromPositionV(.{ r_x, y, z, 0 });
                    const r_bd: block.BlockData = block.BlockData.fromId(r_data[r_i]);
                    self.lightCrossing(c_data, c_i, &c_bd, r_bd, .left);
                }
            }
        }
    }
};

const std = @import("std");
const game = @import("../../game.zig");
const blecs = @import("../../blecs/blecs.zig");
const data = @import("../../data/data.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");
const save_job = @import("jobs_save.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
