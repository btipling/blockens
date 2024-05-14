pub const WorldDescriptorGenJob = struct {
    world_id: i32,
    seed: i32 = 0,
    terrain_scripts: std.ArrayListUnmanaged(data.colorScriptOption) = .{},

    pub fn exec(self: *WorldDescriptorGenJob) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("WorldDescriptorGen");
            const tracy_zone = ztracy.ZoneNC(@src(), "WorldDescriptorGen", 0xF0_00_ff_f0);
            defer tracy_zone.End();
            self.worldDescriptorGenJob();
        } else {
            self.worldDescriptorGenJob();
        }
    }

    pub fn worldDescriptorGenJob(self: *WorldDescriptorGenJob) void {
        self.loadWorldData();
        errdefer self.terrain_scripts.deinit();
        var descriptors = std.ArrayList(*descriptor.root).init(game.state.allocator);
        errdefer errClearDescriptors(descriptors);
        for (self.terrain_scripts.items) |ts| {
            var scriptData: data.colorScript = undefined;
            game.state.db.loadTerrainGenScript(ts.id, &scriptData) catch @panic("db error");
            const script_buf: []const u8 = std.mem.sliceTo(&scriptData.script, 0);
            const desc_root: *descriptor.root = game.state.script.evalTerrainFunc(
                script_buf,
            ) catch |err| {
                std.debug.print("Error evaluating terrain gen function: {}\n", .{err});
                return;
            };
            descriptors.append(desc_root) catch @panic("OOM");
        }
        self.finishJob(descriptors);
    }

    fn errClearDescriptors(descriptors: std.ArrayList(*descriptor.root)) void {
        for (descriptors.items) |d| d.deinit();
        descriptors.deinit();
    }

    fn loadWorldData(self: *WorldDescriptorGenJob) void {
        errdefer self.terrain_scripts.deinit(game.state.allocator);
        var w: data.world = undefined;
        game.state.db.loadWorld(self.world_id, &w) catch @panic("db error");
        self.seed = w.seed;
        game.state.db.listWorldTerrains(
            self.world_id,
            game.state.ui.allocator,
            &self.terrain_scripts,
        ) catch @panic("db error");
    }

    fn finishJob(self: *WorldDescriptorGenJob, descriptors: std.ArrayList(*descriptor.root)) void {
        errdefer errClearDescriptors(descriptors);
        std.debug.print("Generated descriptor in job\n", .{});
        self.terrain_scripts.deinit(game.state.allocator);
        var msg: buffer.buffer_message = buffer.new_message(.world_descriptor_gen);
        const bd: buffer.buffer_data = .{
            .world_descriptor_gen = .{
                .world_id = self.world_id,
                .descriptors = descriptors,
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
const data = @import("../../data/data.zig");
const script = @import("../../script/script.zig");
