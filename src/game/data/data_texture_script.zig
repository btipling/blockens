pub fn saveTextureScript(db: sqlite.Database, name: []const u8, textureScript: []const u8) !void {
    var insert_stmt = try db.prepare(
        struct {
            name: sqlite.Text,
            script: sqlite.Text,
        },
        void,
        insert_texture_script_stmt,
    );
    defer insert_stmt.deinit();

    insert_stmt.exec(
        .{
            .name = sqlite.text(name),
            .script = sqlite.text(textureScript),
        },
    ) catch |err| {
        std.log.err("Failed to insert script: {}", .{err});
        return err;
    };
}

pub fn updateTextureScript(db: sqlite.Database, id: i32, name: []const u8, textureScript: []const u8) !void {
    var update_stmt = try db.prepare(
        sql_utils.scriptSQL,
        void,
        update_texture_script_stmt,
    );
    defer update_stmt.deinit();

    update_stmt.exec(
        .{
            .id = id,
            .name = sqlite.text(name),
            .script = sqlite.text(textureScript),
        },
    ) catch |err| {
        std.log.err("Failed to update script: {}", .{err});
        return err;
    };
}

pub fn listTextureScripts(db: sqlite.Database, data: *std.ArrayList(sql_utils.scriptOption)) !void {
    var listStmt = try db.prepare(
        struct {},
        sql_utils.scriptOptionSQL,
        list_texture_stmt,
    );
    defer listStmt.deinit();

    data.clearRetainingCapacity();
    {
        try listStmt.bind(.{});
        defer listStmt.reset();

        while (try listStmt.step()) |r| {
            try data.append(
                sql_utils.scriptOption{
                    .id = r.id,
                    .name = sql_utils.sqlNameToArray(r.name),
                },
            );
        }
    }
}

pub fn loadTextureScript(db: sqlite.Database, id: i32, data: *sql_utils.script) !void {
    var select_stmt = try db.prepare(
        struct {
            id: i32,
        },
        sql_utils.scriptSQL,
        select_texture_stmt,
    );
    defer select_stmt.deinit();

    {
        try select_stmt.bind(.{ .id = id });
        defer select_stmt.reset();

        while (try select_stmt.step()) |r| {
            data.id = r.id;
            data.name = sql_utils.sqlNameToArray(r.name);
            data.script = sql_utils.sqlTextToScript(r.script);
            return;
        }
    }

    return error.Unreachable;
}

pub fn deleteTextureScript(db: sqlite.Database, id: i32) !void {
    var delete_stmt = try db.prepare(
        struct {
            id: i32,
        },
        void,
        delete_texture_stmt,
    );

    delete_stmt.exec(
        .{ .id = id },
    ) catch |err| {
        std.log.err("Failed to delete texture script: {}", .{err});
        return err;
    };
}

const insert_texture_script_stmt = @embedFile("./sql/v3/texture_script/insert.sql");
const update_texture_script_stmt = @embedFile("./sql/v3/texture_script/update.sql");
const select_texture_stmt = @embedFile("./sql/v3/texture_script/select.sql");
const list_texture_stmt = @embedFile("./sql/v3/texture_script/list.sql");
const delete_texture_stmt = @embedFile("./sql/v3/texture_script/delete.sql");

const std = @import("std");
const sqlite = @import("sqlite");
pub const sql_utils = @import("data_sql_utils.zig");
