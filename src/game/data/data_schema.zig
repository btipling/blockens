pub const current_schema_version: i32 = 2;

pub fn ensureSchema(db: sqlite.Database) !void {
    const createTableQueries = [_][]const u8{
        create_world_table,
        create_texture_scripts_table,
        create_block_table,
        create_chunks_script_table,
        create_chunk_data_table,
        create_player_pos_table,
        create_display_settings_table,
        create_schema_table,
    };
    for (createTableQueries) |query| {
        db.exec(query, .{}) catch |err| {
            std.log.err("Failed to create schema: {}", .{err});
            return err;
        };
    }
}

pub fn saveSchema(db: sqlite.Database) !void {
    var insert_stmt = try db.prepare(
        struct {
            version: i32,
        },
        void,
        insert_schema_stmt,
    );
    defer insert_stmt.deinit();

    insert_stmt.exec(
        .{ .version = current_schema_version },
    ) catch |err| {
        std.log.err("Failed to insert schema: {}", .{err});
        return err;
    };
}

pub fn currentSchemaVersion(db: sqlite.Database) !i32 {
    var count_stmt = try db.prepare(
        struct {},
        struct {
            version: i32,
        },
        select_schema_stmt,
    );
    defer count_stmt.deinit();

    defer count_stmt.reset();
    while (try count_stmt.step()) |r| {
        return r.version;
    }

    return 0;
}

const create_player_pos_table = @embedFile("./sql/v2/player_position/create.sql");
const create_world_table = @embedFile("./sql/v2/world/create.sql");
const create_display_settings_table = @embedFile("./sql/v2/display_settings/create.sql");
const create_texture_scripts_table = @embedFile("./sql/v2/texture_script/create.sql");
const create_chunks_script_table = @embedFile("./sql/v2/chunk_script/create.sql");
const create_block_table = @embedFile("./sql/v2/block/create.sql");
const create_chunk_data_table = @embedFile("./sql/v2/chunk/create.sql");

const create_schema_table = @embedFile("./sql/v2/schema/create.sql");
const insert_schema_stmt = @embedFile("./sql/v2/schema/insert.sql");
const select_schema_stmt = @embedFile("./sql/v2/schema/select.sql");

const std = @import("std");
const sqlite = @import("sqlite");
