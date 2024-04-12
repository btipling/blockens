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
};

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
