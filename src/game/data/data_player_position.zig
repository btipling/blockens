pub fn savePlayerPosition(
    db: sqlite.Database,
    world_id: i32,
    pos: @Vector(4, f32),
    rot: @Vector(4, f32),
    angle: f32,
) !void {
    var insert_stmt = try db.prepare(
        struct {
            world_id: i32,
            world_pos_x: f32,
            world_pos_y: f32,
            world_pos_z: f32,
            rot_w: f32,
            rot_x: f32,
            rot_y: f32,
            rot_z: f32,
            rot_angle: f32,
        },
        void,
        insert_player_pos_stmt,
    );
    defer insert_stmt.deinit();

    insert_stmt.exec(
        .{
            .world_id = world_id,
            .world_pos_x = pos[0],
            .world_pos_y = pos[1],
            .world_pos_z = pos[2],
            .rot_w = rot[0],
            .rot_x = rot[1],
            .rot_y = rot[2],
            .rot_z = rot[3],
            .rot_angle = angle,
        },
    ) catch |err| {
        std.log.err("Failed to insert player position: {}", .{err});
        return err;
    };
}

pub fn updatePlayerPosition(
    db: sqlite.Database,
    world_id: i32,
    pos: @Vector(4, f32),
    rot: @Vector(4, f32),
    angle: f32,
) !void {
    var update_stmt = try db.prepare(
        struct {
            world_id: i32,
            world_pos_x: f32,
            world_pos_y: f32,
            world_pos_z: f32,
            rot_w: f32,
            rot_x: f32,
            rot_y: f32,
            rot_z: f32,
            rot_angle: f32,
        },
        void,
        update_player_pos_stmt,
    );
    defer update_stmt.deinit();

    update_stmt.exec(
        .{
            .world_id = world_id,
            .world_pos_x = pos[0],
            .world_pos_y = pos[1],
            .world_pos_z = pos[2],
            .rot_w = rot[0],
            .rot_x = rot[1],
            .rot_y = rot[2],
            .rot_z = rot[3],
            .rot_angle = angle,
        },
    ) catch |err| {
        std.log.err("Failed to update player position: {}", .{err});
        return err;
    };
}

pub const playerPosition = struct {
    id: i32 = 0,
    world_id: i32 = 0,
    pos: @Vector(4, f32) = undefined,
    rot: @Vector(4, f32) = undefined,
    angle: f32 = 0,
};

pub fn loadPlayerPosition(db: sqlite.Database, world_id: i32, data: *playerPosition) !void {
    var select_stmt = try db.prepare(
        struct {
            world_id: i32,
        },
        struct {
            id: i32,
            world_id: i32,
            world_pos_x: f32,
            world_pos_y: f32,
            world_pos_z: f32,
            rot_w: f32,
            rot_x: f32,
            rot_y: f32,
            rot_z: f32,
            rot_angle: f32,
        },
        select_player_pos_stmt,
    );
    defer select_stmt.deinit();

    {
        try select_stmt.bind(.{ .world_id = world_id });
        defer select_stmt.reset();

        while (try select_stmt.step()) |r| {
            data.id = r.id;
            data.world_id = r.world_id;
            data.pos = .{ r.world_pos_x, r.world_pos_y, r.world_pos_z, 1 };
            data.rot = .{ r.rot_w, r.rot_x, r.rot_y, r.rot_z };
            data.angle = r.rot_angle;
            return;
        }
    }

    return sql_utils.DataErr.NotFound;
}

pub fn deletePlayerPosition(db: sqlite.Database, world_id: i32) !void {
    var delete_stmt = try db.prepare(
        struct {
            world_id: i32,
        },
        void,
        delete_player_pos_stmt,
    );

    delete_stmt.exec(
        .{ .world_id = world_id },
    ) catch |err| {
        std.log.err("Failed to delete player position: {}", .{err});
        return err;
    };
}

const insert_player_pos_stmt = @embedFile("./sql/v3/player_position/insert.sql");
const update_player_pos_stmt = @embedFile("./sql/v3/player_position/update.sql");
const select_player_pos_stmt = @embedFile("./sql/v3/player_position/select.sql");
const delete_player_pos_stmt = @embedFile("./sql/v3/player_position/delete.sql");

const std = @import("std");
const sqlite = @import("sqlite");
pub const sql_utils = @import("data_sql_utils.zig");
