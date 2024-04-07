const std = @import("std");
const game = @import("../../game.zig");
const chunk = @import("../../chunk.zig");
const block = @import("../../block.zig");
const blecs = @import("../../blecs/blecs.zig");
const data = @import("../../data/data.zig");
const config = @import("config");

const air: u8 = 0;

pub const LightingJob = struct {
    wp: chunk.worldPosition,
    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("LightingJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "LightingJob", 0x00_C0_82_f0);
            defer tracy_zone.End();
            self.lightingJob();
        } else {
            self.lightingJob();
        }
    }

    pub fn lightingJob(self: *@This()) void {
        var mapped: [chunk.chunkDim][chunk.chunkDim][chunk.chunkDim]bool = std.mem.zeroes(
            [chunk.chunkDim][chunk.chunkDim][chunk.chunkDim]bool,
        );
        const p = chunk.worldPosition.vecFromWorldPosition(self.wp);
        std.debug.print("doing a lighting {}\n", .{
            p,
        });
        const c: *chunk.Chunk = game.state.blocks.game_chunks.get(self.wp) orelse return;
        std.debug.print("got a chunk {}\n", .{c.entity});
        var z: isize = 0;
        while (z < 64) : (z += 1) {
            var x: isize = 0;
            while (x < 64) : (x += 1) {
                var y: isize = 63;
                while (true) : (y -= 1) {
                    // flow in 5 directions and mark any block for that surface as lit
                    const distance: isize = 10;
                    checkPosition(&mapped, c, x, y, z, distance);
                    {
                        // check below, if hit, stop checking for this y.
                        const chunk_index: usize = @intCast(x + y * 64 + z * 64 * 64);
                        var bd: block.BlockData = block.BlockData.fromId(c.data[chunk_index]);
                        if (bd.block_id != air) {
                            bd.setAmbient(.top, .full);
                            c.data[chunk_index] = bd.toId();
                            break;
                        }
                    }
                    mapped[@intCast(x)][@intCast(y)][@intCast(z)] = true;
                    if (y == 0) break;
                }
            }
        }
        std.debug.print("done looking at blockoboyos\n", .{});
    }
};

fn checkPosition(
    mapped: *[chunk.chunkDim][chunk.chunkDim][chunk.chunkDim]bool,
    c: *chunk.Chunk,
    x: isize,
    y: isize,
    z: isize,
    distance: isize,
) void {
    if (x < 0 or x >= chunk.chunkDim) return;
    if (y < 0 or y >= chunk.chunkDim) return;
    if (z < 0 or z >= chunk.chunkDim) return;
    if (distance < 0) return;
    if (mapped[@intCast(x)][@intCast(y)][@intCast(z)]) return;
    mapped[@intCast(x)][@intCast(y)][@intCast(z)] = true;
    {
        // front: z+
        const _z = z + distance;
        const chunk_index: usize = @intCast(x + y * 64 + _z * 64 * 64);
        if (chunk_index < chunk.chunkSize) {
            var bd: block.BlockData = block.BlockData.fromId(c.data[chunk_index]);
            if (bd.block_id != air) {
                switch (distance) {
                    1 => bd.setAmbient(.front, .full),
                    2 => bd.setAmbient(.front, .bright),
                    else => bd.setAmbient(.front, .dark),
                }
                c.data[chunk_index] = bd.toId();
            } else {
                checkPosition(mapped, c, x, y, _z, distance - 1);
            }
        }
    }
    {
        // back: z-
        const _z = z - distance;
        const ci: isize = x + y * 64 + _z * 64 * 64;
        if (ci >= 0) {
            const chunk_index: usize = @intCast(ci);
            var bd: block.BlockData = block.BlockData.fromId(c.data[chunk_index]);
            if (bd.block_id != air) {
                switch (distance) {
                    1 => bd.setAmbient(.back, .full),
                    2 => bd.setAmbient(.back, .bright),
                    else => bd.setAmbient(.back, .dark),
                }
                c.data[chunk_index] = bd.toId();
            } else {
                checkPosition(mapped, c, x, y, _z, distance - 1);
            }
        }
    }
    {
        // left: x+
        const _x = x + distance;
        const chunk_index: usize = @intCast(_x + y * 64 + z * 64 * 64);
        if (chunk_index < chunk.chunkSize) {
            var bd: block.BlockData = block.BlockData.fromId(c.data[chunk_index]);
            if (bd.block_id != air) {
                switch (distance) {
                    1 => bd.setAmbient(.left, .full),
                    2 => bd.setAmbient(.left, .bright),
                    else => bd.setAmbient(.left, .dark),
                }
                c.data[chunk_index] = bd.toId();
            } else {
                checkPosition(mapped, c, _x, y, z, distance - 1);
            }
        }
    }
    {
        // right: x-
        const _x = x - distance;
        const ci: isize = _x + y * 64 + z * 64 * 64;
        if (ci >= 0) {
            const chunk_index: usize = @intCast(ci);
            var bd: block.BlockData = block.BlockData.fromId(c.data[chunk_index]);
            if (bd.block_id != air) {
                switch (distance) {
                    1 => bd.setAmbient(.right, .full),
                    2 => bd.setAmbient(.right, .bright),
                    else => bd.setAmbient(.right, .dark),
                }
                if (distance > 1 and bd.block_id != 10) {
                    std.debug.print("right x- {} distance: {} block_id: {}\n", .{ x, distance, bd.block_id });
                }
                c.data[chunk_index] = bd.toId();
            } else {
                checkPosition(mapped, c, _x, y, z, distance - 1);
            }
        }
    }
    {
        // below: y-
        const _y = y - distance;
        const ci: isize = x + _y * 64 + z * 64 * 64;
        if (ci >= 0) {
            const chunk_index: usize = @intCast(ci);
            var bd: block.BlockData = block.BlockData.fromId(c.data[chunk_index]);
            if (bd.block_id != air) {
                switch (distance) {
                    1 => bd.setAmbient(.top, .full),
                    2 => bd.setAmbient(.top, .bright),
                    else => bd.setAmbient(.top, .dark),
                }
                if (distance > 1 and bd.block_id != 10) {
                    std.debug.print("right x- {} distance: {} block_id: {}\n", .{ x, distance, bd.block_id });
                }
                c.data[chunk_index] = bd.toId();
            } else {
                checkPosition(mapped, c, x, _y, z, distance - 1);
            }
        }
    }
}
