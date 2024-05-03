pub const v1_world_chunk_dims: u32 = 8;
pub const v1_chunk_dim = 64;
pub const v1_chunk_size: comptime_int = v1_chunk_dim * v1_chunk_dim * v1_chunk_dim;

pub fn migrate(allocator: std.mem.Allocator) !void {
    var db_v1 = try v1.Data.init(allocator);
    defer db_v1.deinit();
    var db_v2 = try v2.Data.init(allocator);
    defer db_v2.deinit();

    var world_list = std.ArrayList(v1.worldOption).init(allocator);
    defer world_list.deinit();

    try db_v1.listWorlds(&world_list);
    // for each world
    for (world_list.items) |world| migrateWorld(allocator, &db_v1, world.id);

    db_v1.db.exec("ALTER TABLE chunk DROP COLUMN voxels;", .{}) catch |err| {
        std.log.err("Failed to drop chunk's voxel column: {}", .{err});
        return err;
    };

    // Cleans up unused space.
    db_v1.db.exec("VACUUM", .{}) catch |err| {
        std.log.err("Failed to vacuum chunk's voxel column: {}", .{err});
        return err;
    };
}

fn migrateWorld(allocator: std.mem.Allocator, db_v1: *v1.Data, world_id: i32) void {
    for (0..v1_world_chunk_dims) |i| {
        const x: i32 = @as(i32, @intCast(i)) - @as(i32, @intCast(v1_world_chunk_dims / 2));
        for (0..v1_world_chunk_dims) |ii| {
            const z: i32 = @as(i32, @intCast(ii)) - @as(i32, @intCast(v1_world_chunk_dims / 2));
            chunk.column.prime(x, z);

            var num_chunks_found: usize = 0;

            const top_chunk_v1: []u32 = tc1: {
                const cdata = loadV1Chunks(db_v1, world_id, x, 1, z) catch {
                    // do something
                    const fbdata = allocator.alloc(u32, v1_chunk_size) catch @panic("OOM");
                    @memset(fbdata, 0);
                    break :tc1 fbdata;
                };
                num_chunks_found += 1;
                break :tc1 cdata;
            };
            defer allocator.free(top_chunk_v1);
            const bottom_chunk_v1: []u32 = tc1: {
                const cdata = loadV1Chunks(db_v1, world_id, x, 0, z) catch {
                    // do something
                    const fbdata = allocator.alloc(u32, v1_chunk_size) catch @panic("OOM");
                    @memset(fbdata, 0);
                    break :tc1 fbdata;
                };
                num_chunks_found += 1;
                break :tc1 cdata;
            };
            defer allocator.free(bottom_chunk_v1);

            if (num_chunks_found == 0) continue;

            const top_chunk_v2 = allocator.alloc(u64, v1_chunk_size) catch @panic("OOM");
            defer allocator.free(top_chunk_v2);
            const bottom_chunk_v2 = allocator.alloc(u64, v1_chunk_size) catch @panic("OOM");
            defer allocator.free(bottom_chunk_v2);
            var ci: usize = 0;
            while (ci <= v1_chunk_size) : (ci += 1) {
                top_chunk_v2[i] = @intCast(top_chunk_v1[i]);
                bottom_chunk_v2[i] = @intCast(bottom_chunk_v1[i]);
            }

            v2.chunk_file.saveChunkData(
                allocator,
                world_id,
                x,
                z,
                top_chunk_v2,
                bottom_chunk_v2,
            );
        }
    }
}

fn loadV1Chunks(db_v1: *v1.Data, world_id: i32, x: i32, y: i32, z: i32) ![]u32 {
    var chunkData = v1.chunkData{};
    db_v1.loadChunkData(world_id, x, y, z, &chunkData) catch {
        return v1.DataErr.NotFound;
    };
    return chunkData.voxels;
}

const std = @import("std");
const v1 = @import("data.v1.zig");
const v2 = @import("../../data.zig");
const block = @import("../../../block/block.zig");
const chunk = block.chunk;
