pub const RGBAColorTextureSize = 3 * 16 * 16; // 768
// 768 i32s fit into 3072 u8s
pub const TextureBlobArrayStoreSize = 3072;

pub const blockOptionSQL = struct {
    id: i32,
    name: sqlite.Text,
};

pub const blockSQL = struct {
    id: i32,
    name: sqlite.Text,
    texture: sqlite.Blob,
    light_level: i32,
    transparent: i32,
};

pub const blockOption = struct {
    id: u8,
    name: [21]u8,
};

pub const block = struct {
    id: u8 = 0,
    name: [21]u8 = [_]u8{0} ** 21,
    texture: []u32 = undefined,
    light_level: u8 = 0,
    transparent: bool = false,
};

pub fn saveBlock(db: sqlite.Database, name: []const u8, texture: []u32, transparent: bool, light_level: u8) !void {
    var insert_stmt = try db.prepare(
        struct {
            name: sqlite.Text,
            texture: sqlite.Blob,
            light_level: i32,
            transparent: i32,
        },
        void,
        insert_block_stmt,
    );
    defer insert_stmt.deinit();

    var t = textureToBlob(texture);
    var t_int: i32 = 0;
    if (transparent) t_int = 1;
    insert_stmt.exec(
        .{
            .name = sqlite.text(name),
            .texture = sqlite.blob(&t),
            .light_level = @intCast(light_level),
            .transparent = t_int,
        },
    ) catch |err| {
        std.log.err("Failed to insert block: {}", .{err});
        return err;
    };
}

pub fn updateBlock(db: sqlite.Database, id: i32, name: []const u8, texture: []u32, transparent: bool, light_level: u8) !void {
    var update_stmt = try db.prepare(
        struct {
            id: i32,
            name: sqlite.Text,
            texture: sqlite.Blob,
            light_level: i32,
            transparent: i32,
        },
        void,
        update_block_stmt,
    );
    defer update_stmt.deinit();

    var t = textureToBlob(texture);
    var t_int: i32 = 0;
    if (transparent) t_int = 1;
    update_stmt.exec(
        .{
            .id = id,
            .name = sqlite.text(name),
            .texture = sqlite.blob(&t),
            .light_level = @intCast(light_level),
            .transparent = t_int,
        },
    ) catch |err| {
        std.log.err("Failed to update block: {}", .{err});
        return err;
    };
}

pub fn listBlocks(db: sqlite.Database, data: *std.ArrayList(blockOption)) !void {
    var listStmt = try db.prepare(
        struct {},
        blockOptionSQL,
        list_block_stmt,
    );
    defer listStmt.deinit();

    data.clearRetainingCapacity();
    {
        try listStmt.bind(.{});
        defer listStmt.reset();

        while (try listStmt.step()) |row| {
            try data.append(
                blockOption{
                    .id = @intCast(row.id),
                    .name = sql_utils.sqlNameToArray(row.name),
                },
            );
        }
    }
}

// caller owns texture data slice
pub fn loadBlock(db: sqlite.Database, id: i32, data: *block) !void {
    var select_stmt = try db.prepare(
        struct {
            id: i32,
        },
        struct {
            id: i32,
            name: sqlite.Text,
            texture: sqlite.Blob,
            light_level: i32,
            transparent: i32,
        },
        select_block_stmt,
    );
    defer select_stmt.deinit();

    {
        try select_stmt.bind(.{ .id = id });
        defer select_stmt.reset();

        while (try select_stmt.step()) |r| {
            data.id = @intCast(r.id);
            data.name = sql_utils.sqlNameToArray(r.name);
            data.texture = try blobToTexture(r.texture);
            data.light_level = @intCast(r.light_level);
            data.transparent = r.transparent == 1;
            return;
        }
    }

    return error.Unreachable;
}

pub fn deleteBlock(db: sqlite.Database, id: i32) !void {
    var delete_stmt = try db.prepare(
        struct {
            id: i32,
        },
        void,
        delete_block_stmt,
    );

    delete_stmt.exec(
        .{ .id = id },
    ) catch |err| {
        std.log.err("Failed to delete block: {}", .{err});
        return err;
    };
}

// I wrote this before I knew about bitcast fwiw
fn textureToBlob(texture: []u32) [TextureBlobArrayStoreSize]u8 {
    var blob: [TextureBlobArrayStoreSize]u8 = undefined;
    for (texture, 0..RGBAColorTextureSize) |t, i| {
        const offset = i * 4;
        const a = @as(u8, @truncate(t >> 24));
        const b = @as(u8, @truncate(t >> 16));
        const g = @as(u8, @truncate(t >> 8));
        const r = @as(u8, @truncate(t));
        blob[offset] = a;
        blob[offset + 1] = b;
        blob[offset + 2] = g;
        blob[offset + 3] = r;
    }
    return blob;
}

fn blobToTexture(blob: sqlite.Blob) ![]u32 {
    var texture: [RGBAColorTextureSize]u32 = undefined;
    for (texture, 0..) |_, i| {
        const offset = i * 4;
        const a = @as(u32, @intCast(blob.data[offset]));
        const b = @as(u32, @intCast(blob.data[offset + 1]));
        const g = @as(u32, @intCast(blob.data[offset + 2]));
        const r = @as(u32, @intCast(blob.data[offset + 3]));
        texture[i] = a << 24 | b << 16 | g << 8 | r;
    }

    const rv: []u32 = try game.state.allocator.alloc(u32, texture.len);
    @memcpy(rv, &texture);
    return rv;
}

const insert_block_stmt = @embedFile("./sql/v2/block/insert.sql");
const update_block_stmt = @embedFile("./sql/v2/block/update.sql");
const select_block_stmt = @embedFile("./sql/v2/block/select.sql");
const list_block_stmt = @embedFile("./sql/v2/block/list.sql");
const delete_block_stmt = @embedFile("./sql/v2/block/delete.sql");

const std = @import("std");
const sqlite = @import("sqlite");
const game = @import("../game.zig");
pub const sql_utils = @import("data_sql_utils.zig");
