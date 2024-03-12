const std = @import("std");
const zjobs = @import("zjobs");
const chunk = @import("../../chunk.zig");
const game = @import("../../game.zig");
const state = @import("../../state/state.zig");
const blecs = @import("../../blecs/blecs.zig");
const chunk_meshing = @import("jobs_chunk_meshing.zig");
const chunk_copy = @import("jobs_copy_chunk.zig");
const generate_demo_chunk = @import("jobs_generate_demo_chunk.zig");
const generate_world_chunk = @import("jobs_generate_world_chunk.zig");

// TODO: none of these jobs should be talking to ecs or changing global state
// need to do a command buffer with locks and progress UI

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

    pub fn meshChunk(self: *Jobs, world: *blecs.ecs.world_t, entity: blecs.ecs.entity_t, c: *chunk.Chunk) zjobs.JobId {
        return self.jobs.schedule(
            zjobs.JobId.none,
            chunk_meshing.ChunkMeshJob{
                .chunk = c,
                .entity = entity,
                .world = world,
            },
        ) catch |e| {
            std.debug.print("error scheduling chunk mesh job: {}\n", .{e});
            return zjobs.JobId.none;
        };
    }

    pub fn copyChunk(self: *Jobs, wp: state.position.worldPosition) zjobs.JobId {
        return self.jobs.schedule(
            zjobs.JobId.none,
            chunk_copy.CopyChunkJob{
                .wp = wp,
            },
        ) catch |e| {
            std.debug.print("error scheduling copy chunk job: {}\n", .{e});
            return zjobs.JobId.none;
        };
    }

    pub fn generateDemoChunk(self: *Jobs) zjobs.JobId {
        return self.jobs.schedule(
            zjobs.JobId.none,
            generate_demo_chunk.GenerateDemoChunkJob{
                .multi_draw = game.state.ui.data.chunk_use_multi_draw,
            },
        ) catch |e| {
            std.debug.print("error scheduling demo chunk job: {}\n", .{e});
            return zjobs.JobId.none;
        };
    }

    pub fn generateWorldChunk(self: *Jobs, wp: state.position.worldPosition, script: []u8) zjobs.JobId {
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
};
