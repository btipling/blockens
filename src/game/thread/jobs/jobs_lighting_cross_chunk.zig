const std = @import("std");
const game = @import("../../game.zig");
const chunk = @import("../../chunk.zig");
const block = @import("../../block.zig");
const blecs = @import("../../blecs/blecs.zig");
const data = @import("../../data/data.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");
const save_job = @import("jobs_save.zig");

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
        std.debug.print("lighting started\n", .{});
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("LightingCrossChunkJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "LightingCrossChunkJob", 0x00_C0_82_f0);
            defer tracy_zone.End();
            self.lightingCrossChunkJob();
        } else {
            self.lightingCrossChunkJob();
        }
        std.debug.print("lighting done \n", .{});
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
                std.debug.print("saved top light data\n", .{});
            }
            {
                game.state.db.updateChunkData(
                    b_c.id,
                    b_c.scriptId,
                    bt_block_data,
                ) catch @panic("failed to save bottom chunk data after lighting");
                std.debug.print("saved bot light data\n", .{});
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
        std.debug.print("writing message done: {}?\n", .{done});
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

    fn fixCrossChunkLighting(self: *LightingCrossChunkJob, wp: chunk.worldPosition, c_data: []u32) void {
        {
            std.debug.print("fixing cross chunk lighting front\n", .{});
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
                    var f_bd: block.BlockData = block.BlockData.fromId(f_data[f_i]);
                    // Two blocks facing each other - no light adjustment
                    if (c_bd.block_id != air and f_bd.block_id != air) continue;
                    // Brighten the air between the two if need be
                    if (c_bd.block_id == air and f_bd.block_id == air) {
                        const c_am = c_bd.getFullAmbiance();
                        const f_am = f_bd.getFullAmbiance();
                        if (c_am == f_am) continue; // isBrighterThan returns true when values are equal
                        if (c_am.isBrighterThan(f_am) and f_am == c_am.getNextDarker()) continue;
                        if (f_am.isBrighterThan(c_am) and c_am == f_am.getNextDarker()) continue;
                        // Only working on this chunk, other chunk will update from this chunk separately.
                        if (c_am.isBrighterThan(f_am)) continue;
                        c_bd.setFullAmbiance(f_am.getNextDarker());
                        c_data[c_i] = c_bd.toId();
                        self.lightFall(c_data, c_i, c_bd.getFullAmbiance());
                        continue;
                    }
                    if (c_bd.block_id == air) {
                        const c_am = c_bd.getFullAmbiance();
                        const f_sam = f_bd.getSurfaceAmbience(.front);
                        if (c_am == f_sam) continue;
                        if (!c_am.isBrighterThan(f_sam)) continue;
                        continue;
                    }
                    if (f_bd.block_id == air) {
                        const f_am = f_bd.getFullAmbiance();
                        const c_sam = c_bd.getSurfaceAmbience(.back);
                        if (f_am == c_sam) continue;
                        if (!f_am.isBrighterThan(c_sam)) continue;
                        c_bd.setAmbient(.back, f_am);
                        c_data[c_i] = c_bd.toId();
                        continue;
                    }
                }
            }
        }
        {
            std.debug.print("fixing cross chunk lighting back\n", .{});
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
                    var b_bd: block.BlockData = block.BlockData.fromId(b_data[b_i]);
                    if (c_bd.block_id != air and b_bd.block_id != air) continue;
                    if (c_bd.block_id == air and b_bd.block_id == air) {
                        const c_am = c_bd.getFullAmbiance();
                        const b_am = b_bd.getFullAmbiance();
                        if (c_am == b_am) continue; // isBrighterThan returns true when values are equal
                        if (c_am.isBrighterThan(b_am) and b_am == c_am.getNextDarker()) continue;
                        if (b_am.isBrighterThan(c_am) and c_am == b_am.getNextDarker()) continue;
                        if (c_am.isBrighterThan(b_am)) continue; // b_am will have to update itself separateley.
                        c_bd.setFullAmbiance(b_am.getNextDarker());
                        c_data[c_i] = c_bd.toId();
                        self.lightFall(c_data, c_i, c_bd.getFullAmbiance());
                        continue;
                    }
                    if (c_bd.block_id == air) {
                        const c_am = c_bd.getFullAmbiance();
                        const b_sam = b_bd.getSurfaceAmbience(.back);
                        if (c_am == b_sam) continue;
                        if (!c_am.isBrighterThan(b_sam)) continue;
                        continue;
                    }
                    if (b_bd.block_id == air) {
                        const b_am = b_bd.getFullAmbiance();
                        const c_sam = c_bd.getSurfaceAmbience(.front);
                        if (b_am == c_sam) continue;
                        if (!b_am.isBrighterThan(c_sam)) continue;
                        c_bd.setAmbient(.front, b_am);
                        c_data[c_i] = c_bd.toId();
                        continue;
                    }
                }
            }
        }
        {
            std.debug.print("fixing cross chunk lighting left\n", .{});
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
                    var l_bd: block.BlockData = block.BlockData.fromId(l_data[l_i]);
                    if (c_bd.block_id != air and l_bd.block_id != air) continue;
                    if (c_bd.block_id == air and l_bd.block_id == air) {
                        const c_am = c_bd.getFullAmbiance();
                        const l_am = l_bd.getFullAmbiance();
                        if (c_am == l_am) continue;
                        if (c_am.isBrighterThan(l_am) and l_am == c_am.getNextDarker()) continue;
                        if (l_am.isBrighterThan(c_am) and c_am == l_am.getNextDarker()) continue;
                        if (c_am.isBrighterThan(l_am)) continue; // other chunk will update itself separately.
                        c_bd.setFullAmbiance(l_am.getNextDarker());
                        c_data[c_i] = c_bd.toId();
                        self.lightFall(c_data, c_i, c_bd.getFullAmbiance());
                        continue;
                    }
                    if (c_bd.block_id == air) {
                        const c_am = c_bd.getFullAmbiance();
                        const l_sam = l_bd.getSurfaceAmbience(.left);
                        if (c_am == l_sam) continue;
                        if (!c_am.isBrighterThan(l_sam)) continue;
                        continue;
                    }
                    if (l_bd.block_id == air) {
                        const l_am = l_bd.getFullAmbiance();
                        const c_sam = c_bd.getSurfaceAmbience(.right);
                        if (l_am == c_sam) continue;
                        if (!l_am.isBrighterThan(c_sam)) continue;
                        c_bd.setAmbient(.right, l_am);
                        c_data[c_i] = c_bd.toId();
                        continue;
                    }
                }
            }
        }
        {
            std.debug.print("fixing cross chunk lighting right\n", .{});
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
                    var r_bd: block.BlockData = block.BlockData.fromId(r_data[r_i]);
                    // Two blocks facing each other - no light adjustment
                    if (c_bd.block_id != air and r_bd.block_id != air) continue;
                    // Brighten the air between the two if need be
                    if (c_bd.block_id == air and r_bd.block_id == air) {
                        const c_am = c_bd.getFullAmbiance();
                        const r_am = r_bd.getFullAmbiance();
                        if (c_am == r_am) continue; // isBrighterThan returns true when values are equal
                        if (c_am.isBrighterThan(r_am) and r_am == c_am.getNextDarker()) continue;
                        if (r_am.isBrighterThan(c_am) and c_am == r_am.getNextDarker()) continue;
                        if (c_am.isBrighterThan(r_am)) continue; // other chunk will update itself separately.
                        c_bd.setFullAmbiance(r_am.getNextDarker());
                        c_data[c_i] = c_bd.toId();
                        self.lightFall(c_data, c_i, c_bd.getFullAmbiance());
                        continue;
                    }
                    if (c_bd.block_id == air) {
                        const c_am = c_bd.getFullAmbiance();
                        const r_sam = r_bd.getSurfaceAmbience(.right);
                        if (c_am == r_sam) continue;
                        if (!c_am.isBrighterThan(r_sam)) continue;
                        continue;
                    }
                    if (r_bd.block_id == air) {
                        const r_am = r_bd.getFullAmbiance();
                        const c_sam = c_bd.getSurfaceAmbience(.left);
                        if (r_am == c_sam) continue;
                        if (!r_am.isBrighterThan(c_sam)) continue;
                        c_bd.setAmbient(.left, r_am);
                        c_data[c_i] = c_bd.toId();
                        continue;
                    }
                }
            }
        }
    }
};
