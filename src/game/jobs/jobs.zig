const std = @import("std");
const zjobs = @import("zjobs");
const gl = @import("zopengl").bindings;
const chunk = @import("../chunk.zig");
const game = @import("../game.zig");
const blecs = @import("../blecs/blecs.zig");
const chunk_meshing = @import("jobs_chunk_meshing.zig");
const generate_demo_chunk = @import("jobs_generate_demo_chunk.zig");

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

    pub fn generateDemoChunk(self: *Jobs) zjobs.JobId {
        return self.jobs.schedule(
            zjobs.JobId.none,
            generate_demo_chunk.GenerateDemoChunkJob{},
        ) catch |e| {
            std.debug.print("error scheduling chunk mesh job: {}\n", .{e});
            return zjobs.JobId.none;
        };
    }
};
