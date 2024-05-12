pub const display_settings = struct {
    fullscreen: bool = false,
    maximized: bool = true,
    decorated: bool = false,
    width: i32 = 0,
    height: i32 = 0,
};

pub fn saveDisplaySettings(
    db: sqlite.Database,
    fullscreen: bool,
    maximized: bool,
    decorated: bool,
    width: i32,
    height: i32,
) !void {
    var insert_stmt = try db.prepare(
        struct {
            fullscreen: i32,
            maximized: i32,
            decorated: i32,
            width: i32,
            height: i32,
        },
        void,
        insert_display_settings_stmt,
    );
    defer insert_stmt.deinit();

    const fs: i32 = if (fullscreen) (1) else 0;
    const mx: i32 = if (maximized) (1) else 0;
    const dr: i32 = if (decorated) (1) else 0;
    insert_stmt.exec(
        .{
            .fullscreen = fs,
            .maximized = mx,
            .decorated = dr,
            .width = width,
            .height = height,
        },
    ) catch |err| {
        std.log.err("Failed to insert display settings: {}", .{err});
        return err;
    };
}

pub fn updateDisplaySettings(
    db: sqlite.Database,
    fullscreen: bool,
    maximized: bool,
    decorated: bool,
    width: i32,
    height: i32,
) !void {
    var update_stmt = try db.prepare(
        struct {
            id: i32,
            fullscreen: i32,
            maximized: i32,
            decorated: i32,
            width: i32,
            height: i32,
        },
        void,
        update_display_settings_stmt,
    );
    defer update_stmt.deinit();

    const fs: i32 = if (fullscreen) (1) else 0;
    const mx: i32 = if (maximized) (1) else 0;
    const dr: i32 = if (decorated) (1) else 0;
    update_stmt.exec(
        .{
            .id = 1,
            .fullscreen = fs,
            .maximized = mx,
            .decorated = dr,
            .width = width,
            .height = height,
        },
    ) catch |err| {
        std.log.err("Failed to update block: {}", .{err});
        return err;
    };
}

pub fn loadDisplaySettings(db: sqlite.Database, ds: *display_settings) !void {
    var select_stmt = try db.prepare(
        struct {
            id: i32,
        },
        struct {
            fullscreen: i32,
            maximized: i32,
            decorated: i32,
            width: i32,
            height: i32,
        },
        select_display_settings_stmt,
    );
    defer select_stmt.deinit();

    {
        try select_stmt.bind(.{ .id = 1 });
        defer select_stmt.reset();

        while (try select_stmt.step()) |r| {
            ds.fullscreen = r.fullscreen == 1;
            ds.maximized = r.maximized == 1;
            ds.decorated = r.decorated == 1;
            ds.width = r.width;
            ds.height = r.height;
            return;
        }
    }

    return sql_utils.DataErr.NotFound;
}

const insert_display_settings_stmt = @embedFile("./sql/v3/display_settings/insert.sql");
const update_display_settings_stmt = @embedFile("./sql/v3/display_settings/update.sql");
const select_display_settings_stmt = @embedFile("./sql/v3/display_settings/select.sql");
const list_display_settings_stmt = @embedFile("./sql/v3/display_settings/list.sql");
const delete_display_settings_stmt = @embedFile("./sql/v3/display_settings/delete.sql");

const std = @import("std");
const sqlite = @import("sqlite");
pub const sql_utils = @import("data_sql_utils.zig");
