pub const StartupJob = struct {
    pub fn exec(self: *@This()) void {
        if (config.use_tracy) {
            const ztracy = @import("ztracy");
            ztracy.SetThreadName("SaveJob");
            const tracy_zone = ztracy.ZoneNC(@src(), "SaveJob", 0x00_00_ff_f0);
            defer tracy_zone.End();
            self.startUpJob() catch @panic("startup failed");
        } else {
            self.startUpJob() catch @panic("startup failed");
        }
    }

    pub fn startUpJob(self: *@This()) !void {
        std.debug.print("starting up\n", .{});
        self.primeColumns();
        const had_world = game.state.db.ensureDefaultWorld() catch |err| {
            std.log.err("Failed to ensure default world: {}\n", .{err});
            return err;
        };
        if (had_world) {
            self.finishJob();
            return;
        }
        try self.initInitialWorld();
        try self.initInitialPlayer(1);
        self.finishJob();
    }

    pub fn finishJob(_: *@This()) void {
        var msg: buffer.buffer_message = buffer.new_message(.startup);
        buffer.set_progress(&msg, true, 1);
        const bd: buffer.buffer_data = .{
            .startup = .{
                .done = true,
            },
        };
        buffer.put_data(msg, bd) catch @panic("OOM");
        buffer.write_message(msg) catch @panic("unable to write message");
        std.debug.print("done starting up\n", .{});
    }

    pub fn primeColumns(_: @This()) void {
        for (0..game_config.worldChunkDims) |i| {
            const x: i32 = @as(i32, @intCast(i)) - @as(i32, @intCast(game_config.worldChunkDims / 2));
            for (0..game_config.worldChunkDims) |ii| {
                const z: i32 = @as(i32, @intCast(ii)) - @as(i32, @intCast(game_config.worldChunkDims / 2));
                chunk.column.prime(x, z);
            }
        }
    }

    pub fn initInitialWorld(_: *@This()) !void {
        var dirt_texture_script = [_]u8{0} ** script.maxLuaScriptSize;
        const dtsb = @embedFile("../../script/lua/gen_dirt_texture.lua");
        for (dtsb, 0..) |c, i| {
            dirt_texture_script[i] = c;
        }
        const dirt_texture = try game.state.script.evalTextureFunc(dirt_texture_script);
        defer game.state.allocator.free(dirt_texture.?);
        var grass_texture_script = [_]u8{0} ** script.maxLuaScriptSize;
        const gtsb = @embedFile("../../script/lua/gen_grass_texture.lua");
        for (gtsb, 0..) |c, i| {
            grass_texture_script[i] = c;
        }
        const grass_texture = try game.state.script.evalTextureFunc(grass_texture_script);
        defer game.state.allocator.free(grass_texture.?);
        if (dirt_texture == null or grass_texture == null) std.debug.panic("couldn't generate lua textures!\n", .{});
        try game.state.db.saveBlock("dirt", @ptrCast(dirt_texture.?), false, 0);
        try game.state.db.saveBlock("grass", @ptrCast(grass_texture.?), false, 0);
        const default_chunk_script: []const u8 = @embedFile("../../script/lua/chunk_gen_default.lua");
        try game.state.db.savecolorScript("default", default_chunk_script, .{ 0, 1, 0 });
        {
            const top_chunk: []u64 = try game.state.allocator.alloc(u64, chunk.chunkSize);
            defer game.state.allocator.free(top_chunk);
            const bottom_chunk: []u64 = try game.state.allocator.alloc(u64, chunk.chunkSize);
            defer game.state.allocator.free(bottom_chunk);

            // Top chunk is just air
            @memset(top_chunk, chunk.big.fully_lit_air_voxel);

            {
                // bot chunk is a full grass chunk from script
                const bbc = try game.state.script.evalChunkFunc(default_chunk_script);
                defer game.state.allocator.free(bbc);
                var i: usize = 0;
                while (i < chunk.chunkSize) : (i += 1) {
                    bottom_chunk[i] = @intCast(bbc[i]);
                }
            }

            try game.state.db.saveChunkMetadata(1, 0, 1, 0, 0);
            try game.state.db.saveChunkMetadata(1, 0, 0, 0, 1);
            data.chunk_file.saveChunkData(game.state.allocator, 1, 0, 0, top_chunk, bottom_chunk);
        }
    }

    pub fn initInitialPlayer(_: *@This(), world_id: i32) !void {
        const initial_pos: @Vector(4, f32) = .{ 32, 64, 32, 0 };
        const initial_rot: @Vector(4, f32) = .{ 0, 0, 0, 1 };
        const initial_angle: f32 = 0;
        try game.state.db.savePlayerPosition(world_id, initial_pos, initial_rot, initial_angle);
    }
};

const std = @import("std");
const game = @import("../../game.zig");
const data = @import("../../data/data.zig");
const config = @import("config");
const buffer = @import("../buffer.zig");
const script = @import("../../script/script.zig");
const game_config = @import("../../config.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
