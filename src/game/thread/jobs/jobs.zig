const AllJobs = zjobs.JobQueue(.{});

pub const Jobs = struct {
    jobs: zjobs.JobQueue(.{}) = undefined,
    pub fn init() Jobs {
        return .{
            .jobs = AllJobs.init(),
        };
    }

    pub fn deinit(self: *Jobs) void {
        self.jobs.deinit();
    }

    pub fn start(self: *Jobs) void {
        self.jobs.start(.{});
    }

    pub fn start_up(self: *Jobs) zjobs.JobId {
        return self.jobs.schedule(
            zjobs.JobId.none,
            job_startup.StartupJob{},
        ) catch |e| {
            std.debug.print("error scheduling startup job: {}\n", .{e});
            return zjobs.JobId.none;
        };
    }

    pub fn meshChunk(self: *Jobs, world: *blecs.ecs.world_t, entity: blecs.ecs.entity_t, c: *chunk.Chunk) zjobs.JobId {
        return self.jobs.schedule(
            zjobs.JobId.none,
            job_chunk_meshing.ChunkMeshJob{
                .chunk = c,
                .entity = entity,
                .world = world,
            },
        ) catch |e| {
            std.debug.print("error scheduling chunk mesh job: {}\n", .{e});
            return zjobs.JobId.none;
        };
    }

    pub fn generateDemoChunk(self: *Jobs) zjobs.JobId {
        return self.jobs.schedule(
            zjobs.JobId.none,
            generate_demo_chunk.GenerateDemoChunkJob{},
        ) catch |e| {
            std.debug.print("error scheduling demo chunk job: {}\n", .{e});
            return zjobs.JobId.none;
        };
    }

    pub fn generateWorldChunk(self: *Jobs, wp: chunk.worldPosition, script: []u8) zjobs.JobId {
        const s = game.state.allocator.alloc(u8, script.len) catch unreachable;
        @memcpy(s, script);
        return self.jobs.schedule(
            zjobs.JobId.none,
            generate_world_chunk.GenerateWorldChunkJob{
                .wp = wp,
                .script = s,
            },
        ) catch |e| {
            std.debug.print("error scheduling gen world chunk job: {}\n", .{e});
            return zjobs.JobId.none;
        };
    }

    pub fn save_player(self: *Jobs, pp: job_save_player.PlayerPosition) zjobs.JobId {
        return self.jobs.schedule(
            zjobs.JobId.none,
            job_save_player.SavePlayerJob{
                .player_position = pp,
            },
        ) catch |e| {
            std.debug.print("error scheduling save player job: {}\n", .{e});
            return zjobs.JobId.none;
        };
    }

    pub fn save_updated_chunks(self: *Jobs) void {
        var ccl = std.ArrayList(buffer.ChunkColumn).init(game.state.allocator);
        defer ccl.deinit();
        var cs = game.state.blocks.game_chunks.valueIterator();
        while (cs.next()) |cc| {
            const c: *chunk.Chunk = cc.*;
            const pos = c.wp.vecFromWorldPosition();
            const x: i8 = @intFromFloat(pos[0]);
            const z: i8 = @intFromFloat(pos[2]);
            if (!c.updated) continue;
            c.updated = false;
            ccl.append(.{ .x = x, .z = z }) catch @panic("OOM");
        }
        buffer.set_updated_chunks(ccl.items);
        _ = self.jobs.schedule(
            zjobs.JobId.none,
            job_save_chunk.SaveChunkJob{},
        ) catch |e| {
            std.debug.print("error scheduling save chunk job: {}\n", .{e});
            return;
        };
    }

    pub fn lighting(self: *Jobs, world_id: i32) void {
        const pt: *buffer.ProgressTracker = game.state.allocator.create(buffer.ProgressTracker) catch @panic("OOM");
        pt.* = .{
            .num_started = game_config.worldChunkDims * game_config.worldChunkDims,
            .num_completed = 0,
        };
        for (0..game_config.worldChunkDims) |i| {
            const x: i32 = @as(i32, @intCast(i)) - @as(i32, @intCast(game_config.worldChunkDims / 2));
            for (0..game_config.worldChunkDims) |ii| {
                const z: i32 = @as(i32, @intCast(ii)) - @as(i32, @intCast(game_config.worldChunkDims / 2));
                _ = self.jobs.schedule(
                    zjobs.JobId.none,
                    job_lighting.LightingJob{
                        .world_id = world_id,
                        .x = x,
                        .z = z,
                        .pt = pt,
                    },
                ) catch |e| {
                    std.debug.print("error scheduling lighting job: {}\n", .{e});
                    return;
                };
            }
        }
    }

    pub fn lighting_cross_chunk(self: *Jobs, world_id: i32) void {
        const pt: *buffer.ProgressTracker = game.state.allocator.create(buffer.ProgressTracker) catch @panic("OOM");
        pt.* = .{
            .num_started = game_config.worldChunkDims * game_config.worldChunkDims,
            .num_completed = 0,
        };
        for (0..game_config.worldChunkDims) |i| {
            const x: i32 = @as(i32, @intCast(i)) - @as(i32, @intCast(game_config.worldChunkDims / 2));
            for (0..game_config.worldChunkDims) |ii| {
                const z: i32 = @as(i32, @intCast(ii)) - @as(i32, @intCast(game_config.worldChunkDims / 2));
                _ = self.jobs.schedule(
                    zjobs.JobId.none,
                    job_lighting_cross_chunk.LightingCrossChunkJob{
                        .world_id = world_id,
                        .x = x,
                        .z = z,
                        .pt = pt,
                    },
                ) catch |e| {
                    std.debug.print("error scheduling cross chunk lighting job: {}\n", .{e});
                    return;
                };
            }
        }
    }

    pub fn load_chunks(self: *Jobs, world_id: i32, start_game: bool) void {
        const pt: *buffer.ProgressTracker = game.state.allocator.create(buffer.ProgressTracker) catch @panic("OOM");
        pt.* = .{
            .num_started = game_config.worldChunkDims * game_config.worldChunkDims,
            .num_completed = 0,
        };
        for (0..game_config.worldChunkDims) |i| {
            const x: i32 = @as(i32, @intCast(i)) - @as(i32, @intCast(game_config.worldChunkDims / 2));
            for (0..game_config.worldChunkDims) |ii| {
                const z: i32 = @as(i32, @intCast(ii)) - @as(i32, @intCast(game_config.worldChunkDims / 2));
                _ = self.jobs.schedule(
                    zjobs.JobId.none,
                    job_load_chunk.LoadChunkJob{
                        .world_id = world_id,
                        .x = x,
                        .z = z,
                        .start_game = start_game,
                        .pt = pt,
                    },
                ) catch |e| {
                    std.debug.print("error scheduling cross chunk lighting job: {}\n", .{e});
                    return;
                };
            }
        }
    }

    // generateTerrain generates a 2^3 cube of chunks
    pub fn generateDemoDescriptor(
        self: *Jobs,
        offset_x: i32,
        offset_z: i32,
    ) void {
        _ = self.jobs.schedule(
            zjobs.JobId.none,
            job_demo_descriptor_gen.DemoDescriptorGenJob{
                .offset_x = offset_x,
                .offset_z = offset_z,
            },
        ) catch |e| {
            std.debug.print("error scheduling terrain generator job: {}\n", .{e});
            return;
        };
    }

    // generateTerrain generates a 2^3 cube of chunks
    pub fn generateDemoTerrain(
        self: *Jobs,
        desc_root: *descriptor.root,
        offset_x: i32,
        offset_z: i32,
    ) void {
        const pt: *buffer.ProgressTracker = game.state.allocator.create(buffer.ProgressTracker) catch @panic("OOM");
        pt.* = .{
            .num_started = 8,
            .num_completed = 0,
        };
        var i: i32 = 0;
        while (i < 8) : (i += 1) {
            const pos: @Vector(4, i32) = terrain_gen.indexToPosition(i);
            _ = self.jobs.schedule(
                zjobs.JobId.none,
                job_demo_terrain_gen.DemoTerrainGenJob{
                    .desc_root = desc_root,
                    // job will generate terrain for x y z, but use i for actual rendered position
                    .position = .{
                        pos[0] + offset_x,
                        pos[1],
                        pos[2] + offset_z,
                        i,
                    },
                    .pt = pt,
                },
            ) catch |e| {
                std.debug.print("error scheduling terrain generator job: {}\n", .{e});
                return;
            };
        }
    }

    pub fn generateWorld(
        self: *Jobs,
        world_id: i32,
    ) void {
        _ = self.jobs.schedule(
            zjobs.JobId.none,
            job_world_descriptor_gen.WorldDescriptorGenJob{
                .world_id = world_id,
            },
        ) catch |e| {
            std.debug.print("error scheduling world generator job: {}\n", .{e});
            return;
        };
    }
};

const std = @import("std");
const zjobs = @import("zjobs");
const game = @import("../../game.zig");
const state = @import("../../state.zig");
const blecs = @import("../../blecs/blecs.zig");
const job_chunk_meshing = @import("jobs_chunk_meshing.zig");
const generate_demo_chunk = @import("jobs_generate_demo_chunk.zig");
const generate_world_chunk = @import("jobs_generate_world_chunk.zig");
const job_save_player = @import("jobs_save_player.zig");
const job_save_chunk = @import("jobs_save_chunk.zig");
const job_lighting = @import("jobs_lighting.zig");
const job_lighting_cross_chunk = @import("jobs_lighting_cross_chunk.zig");
const job_load_chunk = @import("jobs_load_chunks.zig");
const job_demo_descriptor_gen = @import("jobs_demo_descriptor_gen.zig");
const job_demo_terrain_gen = @import("jobs_demo_terrain_gen.zig");
const job_world_descriptor_gen = @import("jobs_world_descriptor_gen.zig");
const job_startup = @import("jobs_startup.zig");
const buffer = @import("../buffer.zig");
const game_config = @import("../../config.zig");
const terrain_gen = @import("../../block/chunk_terrain_gen.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
const descriptor = chunk.descriptor;
