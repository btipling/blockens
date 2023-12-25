const std = @import("std");
const sqlite = @import("sqlite");

const createWorldTable = @embedFile("./sql/world_create.sql");
const insertWorldStmt = @embedFile("./sql/world_insert.sql");
const selectWorldStmt = @embedFile("./sql/world_select.sql");

const createTextureScriptTable = @embedFile("./sql/texture_script_create.sql");
const insertTextureScriptStmt = @embedFile("./sql/texture_script_insert.sql");
const selectTextureStmt = @embedFile("./sql/texture_script_select.sql");
const listTextureStmt = @embedFile("./sql/texture_script_list.sql");

pub const Data = struct {
    db: sqlite.Db,

    pub fn init() !Data {
        const db = try sqlite.Db.init(.{
            .mode = sqlite.Db.Mode{ .File = "./gamedata.db" },
            .open_flags = .{
                .write = true,
                .create = true,
            },
            .threading_mode = .MultiThread,
        });
        return Data{
            .db = db,
        };
    }

    pub fn ensureSchema(self: *Data) !void {
        const createTableQueries = [_][]const u8{
            createWorldTable,
            createTextureScriptTable,
        };
        for (createTableQueries) |query| {
            var stmt = try self.db.prepareDynamic(query);
            defer stmt.deinit();

            stmt.exec(.{}, .{}) catch |err| {
                std.log.err("Failed to create schema: {}", .{err});
                return err;
            };
        }
    }
    pub fn ensureDefaultWorld(self: *Data) !void {
        // query for the default world
        var selectStmt = try self.db.prepareDynamic(selectWorldStmt);
        defer selectStmt.deinit();

        const row = selectStmt.one(
            struct {
                name: [128:0]u8,
            },
            .{},
            .{ .name = "default" },
        ) catch |err| {
            std.log.err("Failed to query for default world: {}", .{err});
            return err;
        };
        if (row) |r| {
            const n = std.mem.span(r.name[0..].ptr);
            std.debug.print("Found default world: {s}\n", .{n});
            return;
        }
        // insert otherwise
        var insertStmt = try self.db.prepareDynamic(insertWorldStmt);
        defer insertStmt.deinit();

        insertStmt.exec(
            .{},
            .{
                .name = "default",
            },
        ) catch |err| {
            std.log.err("Failed to insert default world: {}", .{err});
            return err;
        };
    }
};
