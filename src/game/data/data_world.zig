pub const worldOption = struct {
    id: i32,
    name: [21]u8,
};

pub const worldOptionSQL = struct {
    id: i32,
    name: sqlite.Text,
};

pub const worldSQL = struct {
    id: i32,
    name: sqlite.Text,
};

pub const world = struct {
    id: i32,
    name: [21]u8,
};

pub fn saveWorld(db: sqlite.Database, name: []const u8) !void {
    var insert_stmt = try db.prepare(
        struct {
            name: sqlite.Text,
        },
        void,
        insert_world_stmt,
    );
    defer insert_stmt.deinit();

    insert_stmt.exec(
        .{ .name = sqlite.text(name) },
    ) catch |err| {
        std.log.err("Failed to insert world: {}", .{err});
        return err;
    };
}

pub fn listWorlds(db: sqlite.Database, data: *std.ArrayList(worldOption)) !void {
    var listStmt = try db.prepare(
        struct {},
        worldOptionSQL,
        listWorldStmt,
    );
    defer listStmt.deinit();

    data.clearRetainingCapacity();
    {
        try listStmt.bind(.{});
        defer listStmt.reset();

        while (try listStmt.step()) |row| {
            chunk_file.initWorldSave(false, row.id);
            try data.append(
                worldOption{
                    .id = row.id,
                    .name = sql_utils.sqlNameToArray(row.name),
                },
            );
        }
    }
}

pub fn loadWorld(db: sqlite.Database, id: i32, data: *world) !void {
    std.debug.print("Loading world: {d}\n", .{id});
    var selectStmt = try db.prepare(
        struct {
            id: i32,
        },
        worldSQL,
        selectWorldByIdStmt,
    );
    defer selectStmt.deinit();

    {
        try selectStmt.bind(.{ .id = id });
        defer selectStmt.reset();

        while (try selectStmt.step()) |r| {
            std.debug.print("Found world: {s}\n", .{r.name.data});
            data.id = r.id;
            data.name = sql_utils.sqlNameToArray(r.name);
            return;
        }
    }

    return error.Unreachable;
}

pub fn updateWorld(db: sqlite.Database, id: i32, name: []const u8) !void {
    var updateStmt = try db.prepare(
        worldSQL,
        void,
        updateWorldStmt,
    );
    defer updateStmt.deinit();

    updateStmt.exec(
        .{
            .id = id,
            .name = sqlite.text(name),
        },
    ) catch |err| {
        std.log.err("Failed to update world: {}", .{err});
        return err;
    };
}

pub fn deleteWorld(db: sqlite.Database, id: i32) !void {
    var deleteStmt = try db.prepare(
        struct {
            id: i32,
        },
        void,
        deleteWorldStmt,
    );

    deleteStmt.exec(.{ .id = id }) catch |err| {
        std.log.err("Failed to delete world: {}", .{err});
        return err;
    };
}

pub fn countWorlds(db: sqlite.Database) !i32 {
    var count_stmt = try db.prepare(
        struct {
            id: i32,
        },
        struct {
            count: i32,
        },
        count_worlds_stmt,
    );
    defer count_stmt.deinit();

    try count_stmt.bind(.{ .id = 0 });
    defer count_stmt.reset();
    while (try count_stmt.step()) |r| {
        return r.count;
    }

    return 0;
}

const insert_world_stmt = @embedFile("./sql/v2/world/insert.sql");
const selectWorldByNameStmt = @embedFile("./sql/v2/world/select_by_name.sql");
const selectWorldByIdStmt = @embedFile("./sql/v2/world/select_by_id.sql");
const listWorldStmt = @embedFile("./sql/v2/world/list.sql");
const updateWorldStmt = @embedFile("./sql/v2/world/update.sql");
const deleteWorldStmt = @embedFile("./sql/v2/world/delete.sql");
const count_worlds_stmt = @embedFile("./sql/v2/world/count_worlds.sql");

const std = @import("std");
const sqlite = @import("sqlite");
pub const sql_utils = @import("data_sql_utils.zig");
pub const chunk_file = @import("chunk_file.zig");
