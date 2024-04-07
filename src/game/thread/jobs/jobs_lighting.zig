const std = @import("std");
const game = @import("../../game.zig");
const chunk = @import("../../chunk.zig");
const block = @import("../../block.zig");
const blecs = @import("../../blecs/blecs.zig");
const data = @import("../../data/data.zig");
const config = @import("config");

const air: u8 = 0;

pub const LightingJob = struct {
    chunk: *chunk.Chunk,
    entity: blecs.ecs.entity_t,
    world: *blecs.ecs.world_t,

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
        _ = game.state.jobs.meshChunk(self.world, self.entity, self.chunk);
        std.debug.print("ended lighting job\n", .{});
    }

    pub fn lightingJob(self: *@This()) void {
        const c: *chunk.Chunk = self.chunk;
        var block_data: [chunk.chunkSize]u32 = std.mem.zeroes([chunk.chunkSize]u32);
        {
            c.mutex.lock();
            defer c.mutex.unlock();
            @memcpy(&block_data, c.data);
        }
        // var mapped: [chunk.chunkSize]bool = std.mem.zeroes([chunk.chunkSize]false);
        var z: isize = 0;
        while (z < 64) : (z += 1) {
            var x: isize = 0;
            while (x < 64) : (x += 1) {
                var y: isize = 63;
                while (true) : (y -= 1) {
                    // flow in 5 directions and mark any block for that surface as lit
                    const distance: isize = 1;
                    checkPosition(&block_data, x, y, z, distance);
                    {
                        const chunk_index: usize = @intCast(x + y * 64 + z * 64 * 64);
                        // check below, if hit, stop checking for this y.
                        var bd: block.BlockData = block.BlockData.fromId(block_data[chunk_index]);
                        if (bd.block_id != air) {
                            bd.setAmbient(.top, .full);
                            block_data[chunk_index] = bd.toId();
                            break;
                        }
                    }
                    if (y == 0) {
                        break;
                    }
                }
            }
        }
        {
            c.mutex.lock();
            defer c.mutex.unlock();
            @memcpy(c.data, &block_data);
        }
    }
};

fn checkPosition(
    block_data: *[chunk.chunkSize]u32,
    x: isize,
    y: isize,
    z: isize,
    distance: isize,
) void {
    if (x < 0 or x >= chunk.chunkDim) return;
    if (y < 0 or y >= chunk.chunkDim) return;
    if (z < 0 or z >= chunk.chunkDim) return;
    if (distance >= 10) return;
    {
        // front: z+
        const _z = z + distance;
        const chunk_index: usize = @intCast(x + y * 64 + _z * 64 * 64);
        if (_z < chunk.chunkDim and chunk_index < chunk.chunkSize) {
            var bd: block.BlockData = block.BlockData.fromId(block_data[chunk_index]);
            if (bd.block_id != air) {
                switch (distance) {
                    1 => bd.setAmbient(.front, .full),
                    2 => bd.setAmbient(.front, .bright),
                    else => bd.setAmbient(.front, .dark),
                }
                block_data[chunk_index] = bd.toId();
            }
        }
    }
    {
        // back: z- only for distance 1:
        const _z = z - distance;
        const ci: isize = x + y * 64 + _z * 64 * 64;
        if (_z >= 0 and ci >= 0) {
            const chunk_index: usize = @intCast(ci);
            var bd: block.BlockData = block.BlockData.fromId(block_data[chunk_index]);
            if (bd.block_id != air) {
                switch (distance) {
                    1 => bd.setAmbient(.back, .full),
                    2 => bd.setAmbient(.back, .bright),
                    else => bd.setAmbient(.back, .dark),
                }
                block_data[chunk_index] = bd.toId();
            }
        }
    }
    {
        // left: x+
        const _x = x + distance;
        const chunk_index: usize = @intCast(_x + y * 64 + z * 64 * 64);
        if (_x < chunk.chunkDim and chunk_index < chunk.chunkSize) {
            var bd: block.BlockData = block.BlockData.fromId(block_data[chunk_index]);
            if (bd.block_id != air) {
                switch (distance) {
                    1 => bd.setAmbient(.left, .full),
                    2 => bd.setAmbient(.left, .bright),
                    else => bd.setAmbient(.left, .dark),
                }
                block_data[chunk_index] = bd.toId();
            }
        }
    }
    {
        // right: x-
        const _x = x - distance;
        const ci: isize = _x + y * 64 + z * 64 * 64;
        if (_x >= 0 and ci >= 0) {
            const chunk_index: usize = @intCast(ci);
            var bd: block.BlockData = block.BlockData.fromId(block_data[chunk_index]);
            if (bd.block_id != air) {
                switch (distance) {
                    1 => bd.setAmbient(.right, .full),
                    2 => bd.setAmbient(.right, .bright),
                    else => bd.setAmbient(.right, .dark),
                }
                block_data[chunk_index] = bd.toId();
            }
        }
    }
    {
        // below: y-
        const _y = y - distance;
        const ci: isize = x + _y * 64 + z * 64 * 64;
        if (_y >= 0 and ci >= 0) {
            const chunk_index: usize = @intCast(ci);
            var bd: block.BlockData = block.BlockData.fromId(block_data[chunk_index]);
            if (bd.block_id != air) {
                switch (distance) {
                    1 => bd.setAmbient(.top, .full),
                    2 => bd.setAmbient(.top, .bright),
                    else => bd.setAmbient(.top, .dark),
                }
                block_data[chunk_index] = bd.toId();
            }
        }
    }
}
