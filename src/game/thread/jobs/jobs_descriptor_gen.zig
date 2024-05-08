pub const DescriptorGenJob = struct {
    offset_x: i32,
    offset_z: i32,
    pub fn exec(self: *DescriptorGenJob) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("DescriptorGen");
            const tracy_zone = ztracy.ZoneNC(@src(), "DescriptorGen", 0xF0_00_ff_f0);
            defer tracy_zone.End();
            self.descriptorGenJob();
        } else {
            self.descriptorGenJob();
        }
    }

    pub fn descriptorGenJob(self: *DescriptorGenJob) void {
        const desc_root: *descriptor.root = game.state.script.evalTerrainFunc(
            &game.state.ui.terrain_gen_buf,
        ) catch |err| {
            std.debug.print("Error evaluating terrain gen function: {}\n", .{err});
            return;
        };
        errdefer desc_root.deinit();
        std.debug.print("Generated descriptor in job\n", .{});
        var msg: buffer.buffer_message = buffer.new_message(.descriptor_gen);
        const bd: buffer.buffer_data = .{
            .descriptor_gen = .{
                .desc_root = desc_root,
                .offset_x = self.offset_x,
                .offset_z = self.offset_z,
            },
        };

        buffer.set_progress(&msg, true, 1);
        buffer.put_data(msg, bd) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("unable to write message");
    }
};

const std = @import("std");
const game = @import("../../game.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
const descriptor = chunk.descriptor;
const state = @import("../../state.zig");
const blecs = @import("../../blecs/blecs.zig");
const buffer = @import("../buffer.zig");
const config = @import("config");
