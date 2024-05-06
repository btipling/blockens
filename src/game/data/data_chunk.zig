pub const chunkDataSQL = struct {
    id: i32,
    world_id: i32,
    x: i32,
    y: i32,
    z: i32,
    scriptId: i32,
};

pub const chunkData = struct {
    id: i32 = 0,
    world_id: i32 = 0,
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    scriptId: i32 = 0,
};

pub fn saveChunkMetadata(db: sqlite.Database, world_id: i32, x: i32, y: i32, z: i32, script_id: i32) !void {
    var insertStmt = try db.prepare(
        struct {
            world_id: i32,
            x: i32,
            y: i32,
            z: i32,
            script_id: i32,
        },
        void,
        insert_chunk_data_stmt,
    );
    defer insertStmt.deinit();

    insertStmt.exec(
        .{
            .world_id = world_id,
            .x = x,
            .y = y,
            .z = z,
            .script_id = script_id,
        },
    ) catch |err| {
        std.log.err("Failed to insert chunkdata: {}", .{err});
        return err;
    };
}

pub fn updateChunkMetadata(db: sqlite.Database, id: i32, script_id: i32) !void {
    var updateStmt = try db.prepare(
        struct {
            id: i32,
            script_id: i32,
        },
        void,
        update_chunk_data_stmt,
    );
    defer updateStmt.deinit();

    updateStmt.exec(
        .{
            .id = id,
            .script_id = script_id,
        },
    ) catch |err| {
        std.log.err("Failed to update chunkdata: {}", .{err});
        return err;
    };
}

pub const worldData = struct {
    world_id: i32,
    x: i32,
    z: i32,
    y: i32,
};

pub fn getWorldDataForChunkId(db: sqlite.Database, id: i32) !worldData {
    var selectStmt = try db.prepare(
        struct {
            id: i32,
        },
        struct {
            world_id: i32,
            x: i32,
            y: i32,
            z: i32,
        },
        select_world_data_for_id_stmt,
    );
    defer selectStmt.deinit();

    {
        try selectStmt.bind(.{
            .id = id,
        });
        defer selectStmt.reset();

        while (try selectStmt.step()) |row| {
            return .{
                .world_id = row.world_id,
                .x = row.x,
                .y = row.y,
                .z = row.z,
            };
        }
    }

    return sql_utils.DataErr.NotFound;
}

pub fn loadChunkMetadata(db: sqlite.Database, world_id: i32, x: i32, y: i32, z: i32, data: *chunkData) !void {
    var selectStmt = try db.prepare(
        struct {
            x: i32,
            y: i32,
            z: i32,
            world_id: i32,
        },
        struct {
            id: i32,
            world_id: i32,
            x: i32,
            y: i32,
            z: i32,
            script_id: i32,
        },
        select_chunk_data_by_coords_stmt,
    );
    defer selectStmt.deinit();

    {
        try selectStmt.bind(.{
            .x = x,
            .y = y,
            .z = z,
            .world_id = world_id,
        });
        defer selectStmt.reset();

        while (try selectStmt.step()) |r| {
            data.id = r.id;
            data.world_id = r.world_id;
            data.x = r.x;
            data.y = r.y;
            data.z = r.z;
            data.scriptId = r.script_id;
            return;
        }
    }

    return sql_utils.DataErr.NotFound;
}

pub fn deleteChunkData(db: sqlite.Database, world_id: i32) !void {
    var deleteStmt = try db.prepare(
        struct {
            world_id: i32,
        },
        void,
        delete_chunk_data_stmt,
    );

    deleteStmt.exec(
        .{ .world_id = world_id },
    ) catch |err| {
        std.log.err("Failed to delete chunkdata: {}", .{err});
        return err;
    };
}

pub fn deleteChunkDataById(db: sqlite.Database, id: i32, world_id: i32) !void {
    var deleteStmt = try db.prepare(
        struct {
            id: i32,
            world_id: i32,
        },
        void,
        delete_chunk_data_by_id_stmt,
    );

    deleteStmt.exec(
        .{ .id = id, .world_id = world_id },
    ) catch |err| {
        std.log.err("Failed to delete data by id: {}", .{err});
        return err;
    };
}

const insert_chunk_data_stmt = @embedFile("./sql/v2/chunk/insert.sql");
const update_chunk_data_stmt = @embedFile("./sql/v2/chunk/update.sql");
const select_chunk_data_by_id_stmt = @embedFile("./sql/v2/chunk/select_by_id.sql");
const select_world_data_for_id_stmt = @embedFile("./sql/v2/chunk/select_world_data_for_id.sql");
const select_chunk_data_by_coords_stmt = @embedFile("./sql/v2/chunk/select_by_coords.sql");
const list_chunk_data_stmt = @embedFile("./sql/v2/chunk/list.sql");
const delete_chunk_data_stmt = @embedFile("./sql/v2/chunk/delete.sql");
const delete_chunk_data_by_id_stmt = @embedFile("./sql/v2/chunk/delete_by_id.sql");

const std = @import("std");
const sqlite = @import("sqlite");
const game = @import("../game.zig");
const game_block = @import("../block/block.zig");
const game_chunk = game_block.chunk;
pub const sql_utils = @import("data_sql_utils.zig");
