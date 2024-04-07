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
        var z: usize = 0;
        while (z < 64) : (z += 1) {
            var x: usize = 0;
            while (x < 64) : (x += 1) {
                var y: usize = 63;
                const air: u8 = 0;
                while (true) : (y -= 1) {
                    const chunk_index = x + y * 64 + z * 64 * 64;
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
                    if (y == 0) break;
                }
            }
        }
        std.debug.print("done looking at blockoboyos\n", .{});
    }
};
