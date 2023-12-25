const std = @import("std");
const sqlite = @import("sqlite");

const createTableSchema = @embedFile("./sql/schema.sql");
const insertWorldStmt = @embedFile("./sql/insert_world.sql");
const selectWorldStmt = @embedFile("./sql/select_world.sql");

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
        var stmt = try self.db.prepareDynamic(createTableSchema);
        defer stmt.deinit();

        stmt.exec(.{}, .{}) catch |err| {
            std.log.err("Failed to create schema: {}", .{err});
            return err;
        };
    }

    pub fn ensureDefaultWorld(self: *Data) !void {
        // query for the default world
        var selectStmt = try self.db.prepareDynamic(selectWorldStmt);
        defer selectStmt.deinit();

        const row = try selectStmt.one(
            struct {
                name: [128:0]u8,
            },
            .{},
            .{ .name = "default" },
        );
        if (row) |r| {
            std.debug.print("Found default world: {s}\n", .{r.name});
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
