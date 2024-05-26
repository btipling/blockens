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

    pub fn meshSubChunk(self: *Jobs, is_terrain: bool, is_settings: bool) void {
        std.debug.print("meshing sub chunks begin\n", .{});
        const pt: *buffer.ProgressTracker = game.state.allocator.create(buffer.ProgressTracker) catch @panic("OOM");
        if (is_settings) {
            const num_jobs = game.state.blocks.generated_settings_chunks.count();
            pt.* = .{
                .num_started = num_jobs,
                .num_completed = 0,
            };
            var it = game.state.blocks.generated_settings_chunks.iterator();
            while (it.next()) |kv| {
                const wp: chunk.worldPosition = kv.key_ptr.*;
                const chunk_data = kv.value_ptr.*;
                self.meshSubChunkForWP(is_terrain, is_settings, wp, chunk_data, pt);
            }
            return;
        }
        const num_jobs = game.state.ui.world_chunk_table_data.count();
        pt.* = .{
            .num_started = num_jobs,
            .num_completed = 0,
        };
        var it = game.state.ui.world_chunk_table_data.iterator();
        while (it.next()) |kv| {
            const wp: chunk.worldPosition = kv.key_ptr.*;
            const c_cfg = kv.value_ptr.*;
            self.meshSubChunkForWP(is_terrain, is_settings, wp, c_cfg.chunkData, pt);
        }
        std.debug.print("meshing sub chunks end\n", .{});
        return;
    }

    fn meshSubChunkForWP(
        self: *Jobs,
        is_terrain: bool,
        is_settings: bool,
        wp: chunk.worldPosition,
        chunk_data: []u32,
        pt: *buffer.ProgressTracker,
    ) void {
        _ = self.jobs.schedule(
            zjobs.JobId.none,
            job_sub_chunk_mesh.SubChunkMeshJob{
                .is_terrain = is_terrain,
                .is_settings = is_settings,
                .wp = wp,
                .chunk_data = chunk_data,
                .pt = pt,
            },
        ) catch |e| {
            std.debug.print("error scheduling sub chunk mesh job: {}\n", .{e});
            return;
        };
        return;
    }

    pub fn cullSubChunks(self: *Jobs) void {
        _ = self.jobs.schedule(
            zjobs.JobId.none,
            job_sub_chunk_cull.SubChunkCullJob{},
        ) catch |e| {
            std.debug.print("error scheduling sub chunk cull job: {}\n", .{e});
            return;
        };
        return;
    }

    pub fn buildSubChunks(self: *Jobs, is_terrain: bool, is_settings: bool) void {
        var sorter: *chunk.sub_chunk.sorter = undefined;
        if (is_settings) {
            sorter = game.state.ui.demo_sub_chunks_sorter;
        } else {
            sorter = game.state.ui.game_sub_chunks_sorter;
        }
        _ = self.jobs.schedule(
            zjobs.JobId.none,
            job_sub_chunk_build.SubChunkBuilderJob{
                .sorter = sorter,
                .is_terrain = is_terrain,
                .is_settings = is_settings,
            },
        ) catch |e| {
            std.debug.print("error scheduling sub chunk build job: {}\n", .{e});
            return;
        };
        return;
    }

    pub fn generateDemoChunk(self: *Jobs, sub_chunks: bool) zjobs.JobId {
        return self.jobs.schedule(
            zjobs.JobId.none,
            job_demo_generate_chunk.GenerateDemoChunkJob{
                .sub_chunks = sub_chunks,
            },
        ) catch |e| {
            std.debug.print("error scheduling demo chunk job: {}\n", .{e});
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

    pub fn loadChunks(self: *Jobs, world_id: i32, start_game: bool, sub_chunks: bool) void {
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
                        .sub_chunks = sub_chunks,
                        .pt = pt,
                    },
                ) catch |e| {
                    std.debug.print("error scheduling load chunks job: {}\n", .{e});
                    return;
                };
            }
        }
    }

    // generateTerrain generates a 2^3 cube of chunks
    pub fn generateDemoDescriptor(
        self: *Jobs,
        sub_chunks: bool,
        offset_x: i32,
        offset_z: i32,
    ) void {
        _ = self.jobs.schedule(
            zjobs.JobId.none,
            job_demo_descriptor_gen.DemoDescriptorGenJob{
                .sub_chunks = sub_chunks,
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
        sub_chunks: bool,
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
                    .sub_chunks = sub_chunks,
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

    pub fn generateWorldTerrain(self: *Jobs, world_id: i32, descriptors: std.ArrayList(*descriptor.root)) void {
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
                    job_world_terrain_gen.WorldTerrainGenJob{
                        .descriptors = descriptors,
                        .world_id = world_id,
                        .x = x,
                        .z = z,
                        .pt = pt,
                    },
                ) catch |e| {
                    std.debug.print("error scheduling world terrain gen job: {}\n", .{e});
                    return;
                };
            }
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

    pub fn findPlayerPosition(
        self: *Jobs,
        world_id: i32,
    ) void {
        _ = self.jobs.schedule(
            zjobs.JobId.none,
            job_find_player_pos.FindPlayerPositionJob{
                .world_id = world_id,
            },
        ) catch |e| {
            std.debug.print("error scheduling finding player position job: {}\n", .{e});
            return;
        };
    }
};

const std = @import("std");
const zjobs = @import("zjobs");
const zm = @import("zmath");
const game = @import("../../game.zig");
const state = @import("../../state.zig");
const blecs = @import("../../blecs/blecs.zig");
const job_chunk_meshing = @import("jobs_chunk_meshing.zig");
const job_sub_chunk_mesh = @import("jobs_sub_chunk_mesh.zig");
const job_sub_chunk_build = @import("jobs_sub_chunk_build.zig");
const job_sub_chunk_cull = @import("jobs_sub_chunk_cull.zig");
const job_demo_generate_chunk = @import("jobs_demo_generate_chunk.zig");
const job_demo_descriptor_gen = @import("jobs_demo_descriptor_gen.zig");
const job_demo_terrain_gen = @import("jobs_demo_terrain_gen.zig");
const job_save_player = @import("jobs_save_player.zig");
const job_save_chunk = @import("jobs_save_chunk.zig");
const job_lighting = @import("jobs_lighting.zig");
const job_lighting_cross_chunk = @import("jobs_lighting_cross_chunk.zig");
const job_load_chunk = @import("jobs_load_chunks.zig");
const job_world_descriptor_gen = @import("jobs_world_descriptor_gen.zig");
const job_world_terrain_gen = @import("jobs_world_terrain_gen.zig");
const job_find_player_pos = @import("jobs_find_player_position.zig");
const job_startup = @import("jobs_startup.zig");
const buffer = @import("../buffer.zig");
const game_config = @import("../../config.zig");
const terrain_gen = @import("../../block/chunk_terrain_gen.zig");
const block = @import("../../block/block.zig");
const chunk = block.chunk;
const descriptor = chunk.descriptor;
