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

pub const LightingJob = struct {
    world_id: i32,
    x: i32,
    z: i32,
    pt: *buffer.ProgressTracker,

    pub fn exec(self: *@This()) void {
        std.debug.print("lighting started\n", .{});
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("LightingJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "LightingJob", 0x00_C0_82_f0);
            defer tracy_zone.End();
            self.lightingJob();
        } else {
            self.lightingJob();
        }
        std.debug.print("lighting done \n", .{});
    }

    pub fn lightingJob(self: *@This()) void {
        var t_c: data.chunkData = .{};
        game.state.db.loadChunkData(self.world_id, self.x, 1, self.z, &t_c) catch {
            self.finishJob();
            return;
        };
        defer game.state.allocator.free(t_c.voxels);
        var b_c: data.chunkData = .{};
        game.state.db.loadChunkData(self.world_id, self.x, 0, self.z, &b_c) catch {
            self.finishJob();
            return;
        };
        defer game.state.allocator.free(b_c.voxels);
        var t_block_data: []u32 = t_c.voxels;
        var bt_block_data: []u32 = b_c.voxels;
        // Clear out all the ambient.
        for (0..chunk.chunkSize) |i| {
            var bd: block.BlockData = block.BlockData.fromId(t_block_data[i]);
            bd.clearAmbient();
            t_block_data[i] = bd.toId();
            bd = block.BlockData.fromId(bt_block_data[i]);
            bd.clearAmbient();
            bt_block_data[i] = bd.toId();
        }
        var z: isize = 0;
        while (z < 64) : (z += 1) {
            var x: isize = 0;
            while (x < 64) : (x += 1) {
                var y: isize = 127;
                while (true) : (y -= 1) {
                    // flow in 5 directions and mark any block for that surface as lit
                    if (y >= 64) {
                        const _y = @mod(y, 64);
                        if (!runY(t_block_data, x, _y, z)) break;
                    } else {
                        if (!runY(bt_block_data, x, y, z)) break;
                        if (y == 0) {
                            break;
                        }
                    }
                }
            }
        }
        var y: i8 = 1;
        while (y >= 0) : (y -= 1) {
            var level: block.BlockLighingLevel = .full;
            while (level != .none) {
                var i: usize = 0;
                while (i < chunk.chunkSize) : (i += 1) {
                    if (y == 1) {
                        setAirBasedOnSurroundings(t_block_data, i);
                    } else {
                        setAirBasedOnSurroundings(bt_block_data, i);
                    }
                }
                level = switch (level) {
                    .full => .bright,
                    .bright => .dark,
                    .dark => .none,
                    .none => .none,
                };
            }
        }
        transferAmbianceToBelow(t_block_data, bt_block_data);
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

    fn finishJob(self: *LightingJob) void {
        var msg: buffer.buffer_message = buffer.new_message(.lighting);
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
        buffer.put_lighting_data(msg, .{
            .x = self.x,
            .z = self.z,
        }) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("unable to write message");
    }
};

// fn fixCrossChunkLighting(c: *chunk.Chunk, c_data: *[chunk.chunkSize]u32) void {
//     {
//         std.debug.print("fixing cross chunk lighting front\n", .{});
//         if (game.state.blocks.game_chunks.get(c.wp.getFrontWP())) |f_c| {
//             // We don't change the other chunk, we just mark it as needing its own lighting run.
//             // we don't mark chunks that trigger lighting jobs as being eligigle for being retriggered themselves
//             // to avoid never ending back and forth lighting jobs.
//             var f_needs_relighting = false;
//             var f_data: [chunk.chunkSize]u32 = std.mem.zeroes([chunk.chunkSize]u32);
//             {
//                 f_c.mutex.lock();
//                 defer f_c.mutex.unlock();
//                 @memcpy(&f_data, f_c.data);
//             }
//             // compare planes 63 z of c and 0 z of f_c
//             const c_z: f32 = 63;
//             const f_z: f32 = 0;
//             var y: f32 = 63;
//             while (y >= 0) : (y -= 1) {
//                 var x: f32 = 0;
//                 while (x < chunk.chunkDim) : (x += 1) {
//                     const c_i = chunk.getIndexFromPositionV(.{ x, y, c_z, 0 });
//                     var c_bd: block.BlockData = block.BlockData.fromId(c_data[c_i]);
//                     const f_i = chunk.getIndexFromPositionV(.{ x, y, f_z, 0 });
//                     var f_bd: block.BlockData = block.BlockData.fromId(f_data[f_i]);
//                     // Two blocks facing each other - no light adjustment
//                     if (c_bd.block_id != air and f_bd.block_id != air) continue;
//                     // Brighten the air between the two if need be
//                     if (c_bd.block_id == air and f_bd.block_id == air) {
//                         const c_am = c_bd.getFullAmbiance();
//                         const f_am = f_bd.getFullAmbiance();
//                         if (c_am == f_am) continue; // isBrighterThan returns true when values are equal
//                         if (c_am.isBrighterThan(f_am) and f_am == c_am.getNextDarker()) continue;
//                         if (f_am.isBrighterThan(c_am) and c_am == f_am.getNextDarker()) continue;
//                         if (c_am.isBrighterThan(f_am)) {
//                             f_bd.setFullAmbiance(c_am.getNextDarker());
//                             f_needs_relighting = true;
//                             continue;
//                         }
//                         c_bd.setFullAmbiance(f_am.getNextDarker());
//                         c_data[c_i] = c_bd.toId();
//                         continue;
//                     }
//                     if (c_bd.block_id == air) {
//                         const c_am = c_bd.getFullAmbiance();
//                         const f_sam = f_bd.getSurfaceAmbience(.front);
//                         if (c_am == f_sam) continue;
//                         if (!c_am.isBrighterThan(f_sam)) continue;
//                         f_needs_relighting = true;
//                         continue;
//                     }
//                     if (f_bd.block_id == air) {
//                         const f_am = f_bd.getFullAmbiance();
//                         const c_sam = c_bd.getSurfaceAmbience(.back);
//                         if (f_am == c_sam) continue;
//                         if (!f_am.isBrighterThan(c_sam)) continue;
//                         c_bd.setAmbient(.back, f_am);
//                         c_data[c_i] = c_bd.toId();
//                         continue;
//                     }
//                 }
//             }
//         }
//     }
//     {
//         std.debug.print("fixing cross chunk lighting back\n", .{});
//         if (game.state.blocks.game_chunks.get(c.wp.getBackWP())) |b_c| {
//             var b_needs_relighting = false;
//             var b_data: [chunk.chunkSize]u32 = std.mem.zeroes([chunk.chunkSize]u32);
//             {
//                 b_c.mutex.lock();
//                 defer b_c.mutex.unlock();
//                 @memcpy(&b_data, b_c.data);
//             }
//             // compare planes 0 z of c and 63 z of b_c
//             const c_z: f32 = 0;
//             const b_z: f32 = 63;
//             var y: f32 = 63;
//             while (y >= 0) : (y -= 1) {
//                 var x: f32 = 0;
//                 while (x < chunk.chunkDim) : (x += 1) {
//                     const c_i = chunk.getIndexFromPositionV(.{ x, y, c_z, 0 });
//                     var c_bd: block.BlockData = block.BlockData.fromId(c_data[c_i]);
//                     const b_i = chunk.getIndexFromPositionV(.{ x, y, b_z, 0 });
//                     var b_bd: block.BlockData = block.BlockData.fromId(b_data[b_i]);
//                     if (c_bd.block_id != air and b_bd.block_id != air) continue;
//                     if (c_bd.block_id == air and b_bd.block_id == air) {
//                         const c_am = c_bd.getFullAmbiance();
//                         const b_am = b_bd.getFullAmbiance();
//                         if (c_am == b_am) continue; // isBrighterThan returns true when values are equal
//                         if (c_am.isBrighterThan(b_am) and b_am == c_am.getNextDarker()) continue;
//                         if (b_am.isBrighterThan(c_am) and c_am == b_am.getNextDarker()) continue;
//                         if (c_am.isBrighterThan(b_am)) {
//                             b_bd.setFullAmbiance(c_am.getNextDarker());
//                             b_needs_relighting = true;
//                             continue;
//                         }
//                         c_bd.setFullAmbiance(b_am.getNextDarker());
//                         c_data[c_i] = c_bd.toId();
//                         continue;
//                     }
//                     if (c_bd.block_id == air) {
//                         const c_am = c_bd.getFullAmbiance();
//                         const b_sam = b_bd.getSurfaceAmbience(.back);
//                         if (c_am == b_sam) continue;
//                         if (!c_am.isBrighterThan(b_sam)) continue;
//                         b_needs_relighting = true;
//                         continue;
//                     }
//                     if (b_bd.block_id == air) {
//                         const b_am = b_bd.getFullAmbiance();
//                         const c_sam = c_bd.getSurfaceAmbience(.front);
//                         if (b_am == c_sam) continue;
//                         if (!b_am.isBrighterThan(c_sam)) continue;
//                         c_bd.setAmbient(.front, b_am);
//                         c_data[c_i] = c_bd.toId();
//                         continue;
//                     }
//                 }
//             }
//         }
//     }
//     {
//         std.debug.print("fixing cross chunk lighting left\n", .{});
//         if (game.state.blocks.game_chunks.get(c.wp.getLeftWP())) |l_c| {
//             var l_needs_relighting = false;
//             var l_data: [chunk.chunkSize]u32 = std.mem.zeroes([chunk.chunkSize]u32);
//             {
//                 l_c.mutex.lock();
//                 defer l_c.mutex.unlock();
//                 @memcpy(&l_data, l_c.data);
//             }
//             // compare planes 63 x of c and 0 x of l_c
//             const c_x: f32 = 63;
//             const l_x: f32 = 0;
//             var y: f32 = 63;
//             while (y >= 0) : (y -= 1) {
//                 var z: f32 = 0;
//                 while (z < chunk.chunkDim) : (z += 1) {
//                     const c_i = chunk.getIndexFromPositionV(.{ c_x, y, z, 0 });
//                     var c_bd: block.BlockData = block.BlockData.fromId(c_data[c_i]);
//                     const l_i = chunk.getIndexFromPositionV(.{ l_x, y, z, 0 });
//                     var l_bd: block.BlockData = block.BlockData.fromId(l_data[l_i]);
//                     if (c_bd.block_id != air and l_bd.block_id != air) continue;
//                     if (c_bd.block_id == air and l_bd.block_id == air) {
//                         const c_am = c_bd.getFullAmbiance();
//                         const l_am = l_bd.getFullAmbiance();
//                         if (c_am == l_am) continue;
//                         if (c_am.isBrighterThan(l_am) and l_am == c_am.getNextDarker()) continue;
//                         if (l_am.isBrighterThan(c_am) and c_am == l_am.getNextDarker()) continue;
//                         if (c_am.isBrighterThan(l_am)) {
//                             l_bd.setFullAmbiance(c_am.getNextDarker());
//                             l_needs_relighting = true;
//                             continue;
//                         }
//                         c_bd.setFullAmbiance(l_am.getNextDarker());
//                         c_data[c_i] = c_bd.toId();
//                         continue;
//                     }
//                     if (c_bd.block_id == air) {
//                         const c_am = c_bd.getFullAmbiance();
//                         const l_sam = l_bd.getSurfaceAmbience(.left);
//                         if (c_am == l_sam) continue;
//                         if (!c_am.isBrighterThan(l_sam)) continue;
//                         l_needs_relighting = true;
//                         continue;
//                     }
//                     if (l_bd.block_id == air) {
//                         const l_am = l_bd.getFullAmbiance();
//                         const c_sam = c_bd.getSurfaceAmbience(.right);
//                         if (l_am == c_sam) continue;
//                         if (!l_am.isBrighterThan(c_sam)) continue;
//                         c_bd.setAmbient(.right, l_am);
//                         c_data[c_i] = c_bd.toId();
//                         continue;
//                     }
//                 }
//             }
//         }
//     }
//     {
//         std.debug.print("fixing cross chunk lighting right\n", .{});
//         if (game.state.blocks.game_chunks.get(c.wp.getRightWP())) |r_c| {
//             var r_needs_relighting = false;
//             var r_data: [chunk.chunkSize]u32 = std.mem.zeroes([chunk.chunkSize]u32);
//             {
//                 r_c.mutex.lock();
//                 defer r_c.mutex.unlock();
//                 @memcpy(&r_data, r_c.data);
//             }
//             // compare planes 0 x of c and 63 x of r_c
//             const c_x: f32 = 0;
//             const r_x: f32 = 63;
//             var y: f32 = 63;
//             while (y >= 0) : (y -= 1) {
//                 var z: f32 = 0;
//                 while (z < chunk.chunkDim) : (z += 1) {
//                     const c_i = chunk.getIndexFromPositionV(.{ c_x, y, z, 0 });
//                     var c_bd: block.BlockData = block.BlockData.fromId(c_data[c_i]);
//                     const r_i = chunk.getIndexFromPositionV(.{ r_x, y, z, 0 });
//                     var r_bd: block.BlockData = block.BlockData.fromId(r_data[r_i]);
//                     // Two blocks facing each other - no light adjustment
//                     if (c_bd.block_id != air and r_bd.block_id != air) continue;
//                     // Brighten the air between the two if need be
//                     if (c_bd.block_id == air and r_bd.block_id == air) {
//                         const c_am = c_bd.getFullAmbiance();
//                         const r_am = r_bd.getFullAmbiance();
//                         if (c_am == r_am) continue; // isBrighterThan returns true when values are equal
//                         if (c_am.isBrighterThan(r_am) and r_am == c_am.getNextDarker()) continue;
//                         if (r_am.isBrighterThan(c_am) and c_am == r_am.getNextDarker()) continue;
//                         if (c_am.isBrighterThan(r_am)) {
//                             r_bd.setFullAmbiance(c_am.getNextDarker());
//                             r_needs_relighting = true;
//                             continue;
//                         }
//                         c_bd.setFullAmbiance(r_am.getNextDarker());
//                         c_data[c_i] = c_bd.toId();
//                         continue;
//                     }
//                     if (c_bd.block_id == air) {
//                         const c_am = c_bd.getFullAmbiance();
//                         const r_sam = r_bd.getSurfaceAmbience(.right);
//                         if (c_am == r_sam) continue;
//                         if (!c_am.isBrighterThan(r_sam)) continue;
//                         r_needs_relighting = true;
//                         continue;
//                     }
//                     if (r_bd.block_id == air) {
//                         const r_am = r_bd.getFullAmbiance();
//                         const c_sam = c_bd.getSurfaceAmbience(.left);
//                         if (r_am == c_sam) continue;
//                         if (!r_am.isBrighterThan(c_sam)) continue;
//                         c_bd.setAmbient(.left, r_am);
//                         c_data[c_i] = c_bd.toId();
//                         continue;
//                     }
//                 }
//             }
//         }
//     }
// }

fn transferAmbianceToBelow(t_data: []u32, b_data: []u32) void {
    for (0..chunk.chunkDim) |_x| {
        const x: f32 = @floatFromInt(_x);
        for (0..chunk.chunkDim) |_z| {
            const z: f32 = @floatFromInt(_z);
            const ti = chunk.getIndexFromPositionV(.{ x, 0, z, 1 });
            const t_bd: block.BlockData = block.BlockData.fromId(t_data[ti]);
            if (t_bd.block_id != air) continue;
            if (t_bd.getFullAmbiance() == .none) continue;
            const bi = chunk.getIndexFromPositionV(.{ x, 63, z, 1 });
            var b_bd: block.BlockData = block.BlockData.fromId(b_data[bi]);
            if (b_bd.block_id == air) continue;
            b_bd.setAmbient(.top, t_bd.getFullAmbiance());
            b_data[bi] = b_bd.toId();
        }
    }
}

fn setAirBasedOnSurroundings(c_data: []u32, i: usize) void {
    var bd: block.BlockData = block.BlockData.fromId(c_data[i]);
    if (bd.block_id != air) return;
    if (bd.getFullAmbiance() != .none) return;
    const block_index = chunk.getPositionAtIndexV(i);
    var brightest_l: block.BlockLighingLevel = .none;
    {
        const ll = isAmbientSource(c_data, .{ block_index[0], block_index[1], block_index[2] + 1, block_index[3] });
        if (ll.isBrighterThan(brightest_l)) brightest_l = ll;
    }
    {
        const ll = isAmbientSource(c_data, .{ block_index[0], block_index[1], block_index[2] - 1, block_index[3] });
        if (ll.isBrighterThan(brightest_l)) brightest_l = ll;
    }
    {
        const ll = isAmbientSource(c_data, .{ block_index[0] + 1, block_index[1], block_index[2], block_index[3] });
        if (ll.isBrighterThan(brightest_l)) brightest_l = ll;
    }
    {
        const ll = isAmbientSource(c_data, .{ block_index[0] - 1, block_index[1], block_index[2], block_index[3] });
        if (ll.isBrighterThan(brightest_l)) brightest_l = ll;
    }
    const ll = brightest_l.getNextDarker();
    if (ll != .none) {
        bd.setFullAmbiance(ll);
        c_data[i] = bd.toId();
        setSurroundingAmbience(c_data, i, ll);
    }
    return;
}

fn setSurroundingAmbience(c_data: []u32, i: usize, level: block.BlockLighingLevel) void {
    const block_index = chunk.getPositionAtIndexV(i);
    setAmbient(
        c_data,
        .{ block_index[0], block_index[1], block_index[2] + 1, block_index[3] },
        level,
        .front,
    );
    setAmbient(
        c_data,
        .{ block_index[0], block_index[1], block_index[2] - 1, block_index[3] },
        level,
        .back,
    );
    setAmbient(
        c_data,
        .{ block_index[0] + 1, block_index[1], block_index[2], block_index[3] },
        level,
        .left,
    );
    setAmbient(
        c_data,
        .{ block_index[0] - 1, block_index[1], block_index[2], block_index[3] },
        level,
        .right,
    );
    setAmbient(
        c_data,
        .{ block_index[0], block_index[1] - 1, block_index[2], block_index[3] },
        level,
        .top,
    );
    setAmbient(
        c_data,
        .{ block_index[0], block_index[1] + 1, block_index[2], block_index[3] },
        level,
        .bottom,
    );
}

fn isAmbientSource(c_data: []u32, pos: @Vector(4, f32)) block.BlockLighingLevel {
    if (pos[0] < 0) return .none;
    if (pos[1] < 0) return .none;
    if (pos[2] < 0) return .none;
    const i = chunk.getIndexFromPositionV(pos);
    const bd = block.BlockData.fromId(c_data[i]);
    if (bd.block_id != air) return .none; // TODO: support transparent blocks.
    return bd.getFullAmbiance();
}

fn setAmbient(
    c_data: []u32,
    pos: @Vector(4, f32),
    level: block.BlockLighingLevel,
    surface: block.BlockSurface,
) void {
    if (pos[0] < 0) return;
    if (pos[1] < 0) return;
    if (pos[2] < 0) return;
    const i = chunk.getIndexFromPositionV(pos);
    var bd = block.BlockData.fromId(c_data[i]);
    if (bd.block_id == air) return;
    bd.setAmbient(surface, level);
    c_data[i] = bd.toId();
}

fn runY(c_data: []u32, x: isize, y: isize, z: isize) bool {
    const chunk_index: usize = @intCast(x + y * 64 + z * 64 * 64);
    // check below, if hit, stop checking for this y.
    var bd: block.BlockData = block.BlockData.fromId(c_data[chunk_index]);
    if (bd.block_id == air) {
        bd.setFullAmbiance(.full);
        c_data[chunk_index] = bd.toId();
        setSurroundingAmbience(c_data, chunk_index, .full);
    } else {
        bd.setAmbient(.top, .full);
        c_data[chunk_index] = bd.toId();
        return false;
    }
    return true;
}
