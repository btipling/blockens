pub fn saveWorldTerrain(db: sqlite.Database, world_id: i32, terrain_gen_script_id: i32) !void {
    var insert_stmt = try db.prepare(
        struct {
            world_id: i32,
            terrain_gen_script_id: i32,
        },
        void,
        insert_world_terrain_stmt,
    );
    defer insert_stmt.deinit();

    insert_stmt.exec(
        .{
            .world_id = world_id,
            .terrain_gen_script_id = terrain_gen_script_id,
        },
    ) catch |err| {
        std.log.err("Failed to insert world terrain: {}", .{err});
        return err;
    };
}

pub fn listWorldTerrains(db: sqlite.Database, data: *std.ArrayList(sql_utils.colorScriptOption)) !void {
    var listStmt = try db.prepare(
        struct {},
        sql_utils.colorScriptOptionSQL,
        list_world_terrain_stmt,
    );
    defer listStmt.deinit();

    data.clearRetainingCapacity();
    {
        try listStmt.bind(.{});
        defer listStmt.reset();

        while (try listStmt.step()) |r| {
            try data.append(
                sql_utils.colorScriptOption{
                    .id = r.id,
                    .name = sql_utils.sqlNameToArray(r.name),
                    .color = sql_utils.integerToColor3(r.color),
                },
            );
        }
    }
}

pub fn deleteWorldTerrain(db: sqlite.Database, id: i32) !void {
    var delete_stmt = try db.prepare(
        struct {
            id: i32,
        },
        void,
        delete_world_terrain_stmt,
    );

    delete_stmt.exec(
        .{ .id = id },
    ) catch |err| {
        std.log.err("Failed to delete world terrain: {}", .{err});
        return err;
    };
}

const insert_world_terrain_stmt = @embedFile("./sql/v3/world_terrain/insert.sql");
const list_world_terrain_stmt = @embedFile("./sql/v3/world_terrain/list.sql");
const delete_world_terrain_stmt = @embedFile("./sql/v3/world_terrain/delete.sql");

const std = @import("std");
const sqlite = @import("sqlite");
pub const sql_utils = @import("data_sql_utils.zig");
