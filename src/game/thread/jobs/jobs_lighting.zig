const std = @import("std");
const game = @import("../../game.zig");
const chunk = @import("../../chunk.zig");
const block = @import("../../block.zig");
const blecs = @import("../../blecs/blecs.zig");
const data = @import("../../data/data.zig");
const config = @import("config");

const air: u8 = 0;

pub const LightingJob = struct {
    x: f32,
    z: f32,

    pub fn exec(self: *@This()) void {
        std.debug.print("started lighting job\n", .{});
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("LightingJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "LightingJob", 0x00_C0_82_f0);
            defer tracy_zone.End();
            self.lightingJob();
        } else {
            self.lightingJob();
        }
        std.debug.print("ended lighting job\n", .{});
    }

    pub fn lightingJob(self: *@This()) void {
        const top_wp: chunk.worldPosition = chunk.worldPosition.initFromPositionV(.{ self.x, 1, self.z, 1 });
        const t_c: *chunk.Chunk = game.state.blocks.game_chunks.get(top_wp) orelse return;
        const bot_wp: chunk.worldPosition = chunk.worldPosition.initFromPositionV(.{ self.x, 0, self.z, 1 });
        const b_c: *chunk.Chunk = game.state.blocks.game_chunks.get(bot_wp) orelse return;
        var t_block_data: [chunk.chunkSize]u32 = std.mem.zeroes([chunk.chunkSize]u32);
        var bt_block_data: [chunk.chunkSize]u32 = std.mem.zeroes([chunk.chunkSize]u32);
        {
            {
                t_c.mutex.lock();
                defer t_c.mutex.unlock();
                @memcpy(&t_block_data, t_c.data);
            }
            {
                b_c.mutex.lock();
                defer b_c.mutex.unlock();
                @memcpy(&bt_block_data, b_c.data);
            }
        }
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
                        if (!runY(&t_block_data, x, _y, z)) break;
                    } else {
                        if (!runY(&bt_block_data, x, y, z)) break;
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
            var down_level: block.BlockLighingLevel = .bright;
            while (level != .none) {
                var i: usize = 0;
                while (i < chunk.chunkSize) : (i += 1) {
                    if (y == 1) {
                        setAirBasedOnSurroundings(&t_block_data, i, down_level);
                    } else {
                        setAirBasedOnSurroundings(&bt_block_data, i, down_level);
                    }
                }
                level = switch (level) {
                    .full => .bright,
                    .bright => .dark,
                    .dark => .none,
                    .none => .none,
                };
                down_level = switch (down_level) {
                    .full => .bright,
                    .bright => .dark,
                    .dark => .none,
                    .none => .none,
                };
            }
        }
        transferAmbianceToBelow(&t_block_data, &bt_block_data);
        {
            const world = game.state.world;
            {
                t_c.mutex.lock();
                defer t_c.mutex.unlock();
                @memcpy(t_c.data, &t_block_data);
                renderChunk(t_c);

                const render_entity = blecs.ecs.get_target(
                    world,
                    t_c.entity,
                    blecs.entities.block.HasChunkRenderer,
                    0,
                );
                _ = game.state.jobs.meshChunk(world, render_entity, t_c);
            }
            {
                b_c.mutex.lock();
                defer b_c.mutex.unlock();
                @memcpy(b_c.data, &bt_block_data);
                renderChunk(b_c);

                const render_entity = blecs.ecs.get_target(
                    world,
                    b_c.entity,
                    blecs.entities.block.HasChunkRenderer,
                    0,
                );
                _ = game.state.jobs.meshChunk(world, render_entity, b_c);
            }
        }
    }
};

fn transferAmbianceToBelow(t_data: *[chunk.chunkSize]u32, b_data: *[chunk.chunkSize]u32) void {
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

fn setAirBasedOnSurroundings(c_data: *[chunk.chunkSize]u32, i: usize, level: block.BlockLighingLevel) void {
    var bd: block.BlockData = block.BlockData.fromId(c_data[i]);
    if (bd.block_id != air) return;
    if (bd.getFullAmbiance() != .none) return;
    const block_index = chunk.getPositionAtIndexV(i);
    var light_up = false;
    if (isAmbientSource(c_data, .{ block_index[0], block_index[1], block_index[2] + 1, block_index[3] })) light_up = true;
    if (isAmbientSource(c_data, .{ block_index[0], block_index[1], block_index[2] - 1, block_index[3] })) light_up = true;
    if (isAmbientSource(c_data, .{ block_index[0] + 1, block_index[1], block_index[2], block_index[3] })) light_up = true;
    if (isAmbientSource(c_data, .{ block_index[0] - 1, block_index[1], block_index[2], block_index[3] })) light_up = true;
    if (light_up) {
        bd.setFullAmbiance(level);
        c_data[i] = bd.toId();
        setSurroundingAmbience(c_data, i, level);
    }
    return;
}

fn setSurroundingAmbience(c_data: *[chunk.chunkSize]u32, i: usize, level: block.BlockLighingLevel) void {
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

fn isAmbientSource(c_data: *[chunk.chunkSize]u32, pos: @Vector(4, f32)) bool {
    if (pos[0] < 0) return false;
    if (pos[1] < 0) return false;
    if (pos[2] < 0) return false;
    const i = chunk.getIndexFromPositionV(pos);
    const bd = block.BlockData.fromId(c_data[i]);
    return bd.block_id == air and bd.getFullAmbiance() != .none;
}

fn setAmbient(
    c_data: *[chunk.chunkSize]u32,
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

fn runY(c_data: *[chunk.chunkSize]u32, x: isize, y: isize, z: isize) bool {
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

fn renderChunk(c: *chunk.Chunk) void {
    const world = game.state.world;
    const render_entity = blecs.ecs.get_target(
        world,
        c.entity,
        blecs.entities.block.HasChunkRenderer,
        0,
    );
    _ = game.state.jobs.meshChunk(world, render_entity, c);
}
