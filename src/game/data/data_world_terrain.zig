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

pub fn listWorldTerrains(
    db: sqlite.Database,
    world_id: i32,
    allocator: std.mem.Allocator,
    data: *std.ArrayListUnmanaged(sql_utils.colorScriptOption),
) !void {
    var list_stmt = try db.prepare(
        struct {
            world_id: i32,
        },
        sql_utils.colorScriptOptionSQL,
        list_world_terrain_stmt,
    );
    defer list_stmt.deinit();

    data.clearRetainingCapacity();
    {
        try list_stmt.bind(.{ .world_id = world_id });
        defer list_stmt.reset();

        while (try list_stmt.step()) |r| {
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

pub fn deleteAllWorldTerrain(db: sqlite.Database, world_id: i32) !void {
    var delete_stmt = try db.prepare(
        struct {
            world_id: i32,
        },
        void,
        delete_all_world_terrain_stmt,
    );

    delete_stmt.exec(
        .{ .world_id = world_id },
    ) catch |err| {
        std.log.err("Failed to delete all world terrain: {}", .{err});
        return err;
    };
}

const insert_world_terrain_stmt = @embedFile("./sql/v3/world_terrain/insert.sql");
const list_world_terrain_stmt = @embedFile("./sql/v3/world_terrain/list.sql");
const delete_world_terrain_stmt = @embedFile("./sql/v3/world_terrain/delete.sql");
const delete_all_world_terrain_stmt = @embedFile("./sql/v3/world_terrain/delete_all.sql");

const std = @import("std");
const sqlite = @import("sqlite");
pub const sql_utils = @import("data_sql_utils.zig");
