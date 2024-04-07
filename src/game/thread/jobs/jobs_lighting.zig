const std = @import("std");
const game = @import("../../game.zig");
const chunk = @import("../../chunk.zig");
const block = @import("../../block.zig");
const blecs = @import("../../blecs/blecs.zig");
const data = @import("../../data/data.zig");
const config = @import("config");

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
                const air: u8 = 0;
                while (true) : (y -= 1) {
                    // check in 5 directions and mark any block for that surface as lit
                    {
                        // front: z+
                        const chunk_index: usize = @intCast(x + y * 64 + (z + 1) * 64 * 64);
                        if (chunk_index < chunk.chunkSize) {
                            var bd: block.BlockData = block.BlockData.fromId(c.data[chunk_index]);
                            if (bd.block_id != air) {
                                bd.setAmbient(.front, .full);
                                c.data[chunk_index] = bd.toId();
                            }
                        }
                    }
                    {
                        // back: z-
                        const ci: isize = x + y * 64 + (z - 1) * 64 * 64;
                        if (ci >= 0) {
                            const chunk_index: usize = @intCast(ci);
                            var bd: block.BlockData = block.BlockData.fromId(c.data[chunk_index]);
                            if (bd.block_id != air) {
                                bd.setAmbient(.back, .full);
                                c.data[chunk_index] = bd.toId();
                            }
                        }
                    }
                    {
                        // left: x+
                        const chunk_index: usize = @intCast((x + 1) + y * 64 + z * 64 * 64);
                        if (chunk_index < chunk.chunkSize) {
                            var bd: block.BlockData = block.BlockData.fromId(c.data[chunk_index]);
                            if (bd.block_id != air) {
                                bd.setAmbient(.left, .full);
                                c.data[chunk_index] = bd.toId();
                            }
                        }
                    }
                    {
                        // right: x-
                        const ci: isize = (x - 1) + y * 64 + z * 64 * 64;
                        if (ci >= 0) {
                            const chunk_index: usize = @intCast(ci);
                            var bd: block.BlockData = block.BlockData.fromId(c.data[chunk_index]);
                            if (bd.block_id != air) {
                                bd.setAmbient(.right, .full);
                                c.data[chunk_index] = bd.toId();
                            }
                        }
                    }
                    {
                        // check below, if hit, stop checking for this y.
                        const chunk_index: usize = @intCast(x + y * 64 + z * 64 * 64);
                        var bd: block.BlockData = block.BlockData.fromId(c.data[chunk_index]);
                        if (bd.block_id != air) {
                            bd.setAmbient(.top, .full);
                            bd.setAmbient(.front, .bright);
                            bd.setAmbient(.back, .bright);
                            bd.setAmbient(.left, .bright);
                            bd.setAmbient(.right, .bright);
                            c.data[chunk_index] = bd.toId();
                            break;
                        }
                    }
                    if (y == 0) break;
                }
            }
        }
        std.debug.print("done looking at blockoboyos\n", .{});
    }
};
