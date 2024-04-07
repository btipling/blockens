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
            while (level != .none) {
                var i: usize = 0;
                while (i < chunk.chunkSize) : (i += 1) {
                    if (y == 1) {
                        setAirBasedOnSurroundings(&t_block_data, i, level);
                    } else {
                        setAirBasedOnSurroundings(&bt_block_data, i, level);
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

        {
            {
                t_c.mutex.lock();
                defer t_c.mutex.unlock();
                @memcpy(t_c.data, &t_block_data);
                renderChunk(t_c);
            }
            {
                b_c.mutex.lock();
                defer b_c.mutex.unlock();
                @memcpy(b_c.data, &bt_block_data);
                renderChunk(b_c);
            }
        }
    }
};

fn setAirBasedOnSurroundings(c_data: *[chunk.chunkSize]u32, i: usize, level: block.BlockLighingLevel) void {
    var bd: block.BlockData = block.BlockData.fromId(c_data[i]);
    if (bd.block_id != air) return;
    if (bd.getFullAmbiance() != .none) return;
    const block_index = chunk.getPositionAtIndexV(i);
    const debug = block_index[0] == 4 and block_index[1] == 1 and block_index[2] == 22;
    if (debug) std.debug.print("seriously wtf??\n", .{});
    var light_up = false;
    if (isAmbientSource(c_data, .{ block_index[0], block_index[1], block_index[2] + 1, block_index[3] }, debug)) light_up = true;
    if (isAmbientSource(c_data, .{ block_index[0], block_index[1], block_index[2] - 1, block_index[3] }, debug)) light_up = true;
    if (isAmbientSource(c_data, .{ block_index[0] + 1, block_index[1], block_index[2], block_index[3] }, debug)) light_up = true;
    if (isAmbientSource(c_data, .{ block_index[0] - 1, block_index[1], block_index[2], block_index[3] }, debug)) light_up = true;
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

fn isAmbientSource(c_data: *[chunk.chunkSize]u32, pos: @Vector(4, f32), debug: bool) bool {
    if (debug) std.debug.print("isAmbientSource pos checking? {}\n", .{pos});
    if (pos[0] < 0) return false;
    if (pos[1] < 0) return false;
    if (pos[2] < 0) return false;
    if (debug) std.debug.print("isAmbientSource pos checking!\n", .{});
    const i = chunk.getIndexFromPositionV(pos);
    const bd = block.BlockData.fromId(c_data[i]);
    if (debug) std.debug.print("isAmbientSource getFullAmbiance: {}\n", .{bd.getFullAmbiance() != .none});
    if (debug) std.debug.print("isAmbientSource is air: {}\n", .{bd.block_id == air});
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

// fn checkPosition(
//     block_data: *[chunk.chunkSize]u32,
//     x: isize,
//     y: isize,
//     z: isize,
//     distance: isize,
// ) void {
//     if (x < 0 or x >= chunk.chunkDim) return;
//     if (y < 0 or y >= chunk.chunkDim) return;
//     if (z < 0 or z >= chunk.chunkDim) return;
//     if (distance >= 10) return;
//     {
//         // front: z+
//         const _z = z + distance;
//         const chunk_index: usize = @intCast(x + y * 64 + _z * 64 * 64);
//         if (_z < chunk.chunkDim and chunk_index < chunk.chunkSize) {
//             var bd: block.BlockData = block.BlockData.fromId(block_data[chunk_index]);
//             if (bd.block_id != air) {
//                 switch (distance) {
//                     1 => bd.setAmbient(.front, .full),
//                     2 => bd.setAmbient(.front, .bright),
//                     else => bd.setAmbient(.front, .dark),
//                 }
//                 block_data[chunk_index] = bd.toId();
//             }
//         }
//     }
//     {
//         // back: z- only for distance 1:
//         const _z = z - distance;
//         const ci: isize = x + y * 64 + _z * 64 * 64;
//         if (_z >= 0 and ci >= 0) {
//             const chunk_index: usize = @intCast(ci);
//             var bd: block.BlockData = block.BlockData.fromId(block_data[chunk_index]);
//             if (bd.block_id != air) {
//                 switch (distance) {
//                     1 => bd.setAmbient(.back, .full),
//                     2 => bd.setAmbient(.back, .bright),
//                     else => bd.setAmbient(.back, .dark),
//                 }
//                 block_data[chunk_index] = bd.toId();
//             }
//         }
//     }
//     {
//         // left: x+
//         const _x = x + distance;
//         const chunk_index: usize = @intCast(_x + y * 64 + z * 64 * 64);
//         if (_x < chunk.chunkDim and chunk_index < chunk.chunkSize) {
//             var bd: block.BlockData = block.BlockData.fromId(block_data[chunk_index]);
//             if (bd.block_id != air) {
//                 switch (distance) {
//                     1 => bd.setAmbient(.left, .full),
//                     2 => bd.setAmbient(.left, .bright),
//                     else => bd.setAmbient(.left, .dark),
//                 }
//                 block_data[chunk_index] = bd.toId();
//             }
//         }
//     }
//     {
//         // right: x-
//         const _x = x - distance;
//         const ci: isize = _x + y * 64 + z * 64 * 64;
//         if (_x >= 0 and ci >= 0) {
//             const chunk_index: usize = @intCast(ci);
//             var bd: block.BlockData = block.BlockData.fromId(block_data[chunk_index]);
//             if (bd.block_id != air) {
//                 switch (distance) {
//                     1 => bd.setAmbient(.right, .full),
//                     2 => bd.setAmbient(.right, .bright),
//                     else => bd.setAmbient(.right, .dark),
//                 }
//                 block_data[chunk_index] = bd.toId();
//             }
//         }
//     }
//     {
//         // below: y-
//         const _y = y - distance;
//         const ci: isize = x + _y * 64 + z * 64 * 64;
//         if (_y >= 0 and ci >= 0) {
//             const chunk_index: usize = @intCast(ci);
//             var bd: block.BlockData = block.BlockData.fromId(block_data[chunk_index]);
//             if (bd.block_id != air) {
//                 switch (distance) {
//                     1 => bd.setAmbient(.top, .full),
//                     2 => bd.setAmbient(.top, .bright),
//                     else => bd.setAmbient(.top, .dark),
//                 }
//                 block_data[chunk_index] = bd.toId();
//             }
//         }
//     }
// }
