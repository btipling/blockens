pub fn saveChunkScript(db: sqlite.Database, name: []const u8, cScript: []const u8, color: [3]f32) !void {
    var insert_stmt = try db.prepare(
        struct {
            name: sqlite.Text,
            script: sqlite.Text,
            color: i32,
        },
        void,
        insert_chunk_script_stmt,
    );
    defer insert_stmt.deinit();

    insert_stmt.exec(
        .{
            .name = sqlite.text(name),
            .script = sqlite.text(cScript),
            .color = sql_utils.colorToInteger3(color),
        },
    ) catch |err| {
        std.log.err("Failed to insert script: {}", .{err});
        return err;
    };
}

pub fn updateChunkScript(db: sqlite.Database, id: i32, name: []const u8, cScript: []const u8, color: [3]f32) !void {
    var update_stmt = try db.prepare(
        sql_utils.colorScriptSQL,
        void,
        update_chunk_script_stmt,
    );
    defer update_stmt.deinit();

    update_stmt.exec(
        .{
            .id = id,
            .name = sqlite.text(name),
            .script = sqlite.text(cScript),
            .color = sql_utils.colorToInteger3(color),
        },
    ) catch |err| {
        std.log.err("Failed to update script: {}", .{err});
        return err;
    };
}

pub fn listChunkScripts(db: sqlite.Database, allocator: std.mem.Allocator, data: *std.ArrayListUnmanaged(sql_utils.colorScriptOption)) !void {
    var listStmt = try db.prepare(
        struct {},
        sql_utils.colorScriptOptionSQL,
        list_chunk_stmt,
    );
    defer listStmt.deinit();

    data.clearRetainingCapacity();
    {
        try listStmt.bind(.{});
        defer listStmt.reset();

        while (try listStmt.step()) |r| {
            try data.append(
                allocator,
                sql_utils.colorScriptOption{
                    .id = r.id,
                    .name = sql_utils.sqlNameToArray(r.name),
                    .color = sql_utils.integerToColor3(r.color),
                },
            );
        }
    }
}

pub fn loadChunkScript(db: sqlite.Database, id: i32, data: *sql_utils.colorScript) !void {
    var select_stmt = try db.prepare(
        struct {
            id: i32,
        },
        sql_utils.colorScriptSQL,
        select_chunk_stmt,
    );
    defer select_stmt.deinit();

    {
        try select_stmt.bind(.{ .id = id });
        defer select_stmt.reset();

        while (try select_stmt.step()) |r| {
            data.id = r.id;
            data.name = sql_utils.sqlNameToArray(r.name);
            data.script = sql_utils.sqlTextToScript(r.script);
            data.color = sql_utils.integerToColor3(r.color);
            return;
        }
    }

    return sql_utils.DataErr.NotFound;
}

pub fn deleteChunkScript(db: sqlite.Database, id: i32) !void {
    var delete_stmt = try db.prepare(
        struct {
            id: i32,
        },
        void,
        delete_chunk_stmt,
    );

    delete_stmt.exec(
        .{ .id = id },
    ) catch |err| {
        std.log.err("Failed to delete chunk script: {}", .{err});
        return err;
    };
}

const insert_chunk_script_stmt = @embedFile("./sql/v3/chunk_script/insert.sql");
const update_chunk_script_stmt = @embedFile("./sql/v3/chunk_script/update.sql");
const select_chunk_stmt = @embedFile("./sql/v3/chunk_script/select.sql");
const list_chunk_stmt = @embedFile("./sql/v3/chunk_script/list.sql");
const delete_chunk_stmt = @embedFile("./sql/v3/chunk_script/delete.sql");

const std = @import("std");
const sqlite = @import("sqlite");
pub const sql_utils = @import("data_sql_utils.zig");
