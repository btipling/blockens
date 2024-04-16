pub const LightingJob = struct {
    world_id: i32,
    x: i32,
    z: i32,
    pt: *buffer.ProgressTracker,

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
        const t_data: []u32 = t_c.voxels;
        const b_data: []u32 = b_c.voxels;
        lighting.light_fall(t_data, b_data);
        {
            {
                game.state.db.updateChunkData(
                    t_c.id,
                    t_c.scriptId,
                    t_data,
                ) catch @panic("failed to save top chunk data after lighting");
            }
            {
                game.state.db.updateChunkData(
                    b_c.id,
                    b_c.scriptId,
                    b_data,
                ) catch @panic("failed to save bottom chunk data after lighting");
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

const std = @import("std");
const game = @import("../../game.zig");
const data = @import("../../data/data.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");
const save_job = @import("jobs_save.zig");
const lighting = @import("../../block/lighting/ambient_fall.zig");
