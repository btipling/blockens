pub const DemoDescriptorGenJob = struct {
    sub_chunks: bool,
    offset_x: i32,
    offset_z: i32,
    pub fn exec(self: *DemoDescriptorGenJob) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("DemoDescriptorGen");
            const tracy_zone = ztracy.ZoneNC(@src(), "DemoDescriptorGen", 0xF0_00_ff_f0);
            defer tracy_zone.End();
            self.demoDescriptorGenJob();
        } else {
            self.demoDescriptorGenJob();
        }
    }

    pub fn demoDescriptorGenJob(self: *DemoDescriptorGenJob) void {
        const script_buf: []const u8 = std.mem.sliceTo(&game.state.ui.terrain_gen_buf, 0);
        const desc_root: *descriptor.root = game.state.script.evalTerrainFunc(
            script_buf,
        ) catch |err| {
            std.debug.print("Error evaluating terrain gen function: {}\n", .{err});
            return;
        };
        errdefer desc_root.deinit();
        std.debug.print("Generated descriptor in job\n", .{});
        var msg: buffer.buffer_message = buffer.new_message(.demo_descriptor_gen);
        const bd: buffer.buffer_data = .{
            .demo_descriptor_gen = .{
                .desc_root = desc_root,
                .sub_chunks = self.sub_chunks,
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
