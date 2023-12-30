const std = @import("std");
const sqlite = @import("sqlite");

const createWorldTable = @embedFile("./sql/world/create.sql");
const insertWorldStmt = @embedFile("./sql/world/insert.sql");
const selectWorldByNameStmt = @embedFile("./sql/world/select_by_name.sql");
const selectWorldByIdStmt = @embedFile("./sql/world/select_by_id.sql");
const listWorldStmt = @embedFile("./sql/world/list.sql");
const updateWorldStmt = @embedFile("./sql/world/update.sql");
const deleteWorldStmt = @embedFile("./sql/world/delete.sql");

const createTextureScriptTable = @embedFile("./sql/texture_script/create.sql");
const insertTextureScriptStmt = @embedFile("./sql/texture_script/insert.sql");
const updateTextureScriptStmt = @embedFile("./sql/texture_script/update.sql");
const selectTextureStmt = @embedFile("./sql/texture_script/select.sql");
const listTextureStmt = @embedFile("./sql/texture_script/list.sql");
const deleteTextureStmt = @embedFile("./sql/texture_script/delete.sql");

pub const scriptOption = struct {
    id: u32,
    name: [21]u8,
};

pub const script = struct {
    id: u32,
    name: [21]u8,
    script: [360_001]u8,
};

pub const worldOption = struct {
    id: u32,
    name: [21]u8,
};

pub const world = struct {
    id: u32,
    name: [21]u8,
};

pub const Data = struct {
    db: sqlite.Db,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !Data {
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
            .alloc = alloc,
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
        var selectStmt = try self.db.prepareDynamic(selectWorldByNameStmt);
        defer selectStmt.deinit();

        const row = selectStmt.one(
            struct {
                name: [20:0]u8,
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
        try saveWorld(self, "default");
    }

    pub fn saveWorld(self: *Data, name: []const u8) !void {
        var insertStmt = try self.db.prepareDynamic(insertWorldStmt);
        defer insertStmt.deinit();

        insertStmt.exec(
            .{},
            .{
                .name = name,
            },
        ) catch |err| {
            std.log.err("Failed to insert world: {}", .{err});
            return err;
        };
    }

    pub fn listWorlds(self: *Data, data: *std.ArrayList(worldOption)) !void {
        var listStmt = try self.db.prepareDynamic(listWorldStmt);
        defer listStmt.deinit();

        data.clearRetainingCapacity();
        const rows = listStmt.all(
            struct {
                id: u32,
                name: [21:0]u8,
            },
            self.alloc,
            .{},
            .{},
        ) catch |err| {
            std.log.err("Failed to list worlds: {}", .{err});
            return err;
        };
        for (rows) |row| {
            try data.append(worldOption{
                .id = row.id,
                .name = row.name,
            });
        }
    }

    pub fn loadWorld(self: *Data, id: u32, data: *world) !void {
        std.debug.print("Loading world: {d}\n", .{id});
        var selectStmt = try self.db.prepareDynamic(selectWorldByIdStmt);
        defer selectStmt.deinit();

        const row = selectStmt.one(
            struct {
                id: u32,
                name: [21:0]u8,
            },
            .{},
            .{ .id = id },
        ) catch |err| {
            std.log.err("Failed to load world: {}", .{err});
            return err;
        };
        if (row) |r| {
            data.id = id;
            data.name = r.name;
            return;
        }
        return error.Unreachable;
    }

    pub fn updateWorld(self: *Data, id: u32, name: []const u8) !void {
        var updateStmt = try self.db.prepareDynamic(updateWorldStmt);
        defer updateStmt.deinit();

        updateStmt.exec(
            .{},
            .{
                .name = name,
                .id = id,
            },
        ) catch |err| {
            std.log.err("Failed to update world: {}", .{err});
            return err;
        };
    }

    pub fn deleteWorld(self: *Data, id: u32) !void {
        var deleteStmt = try self.db.prepareDynamic(deleteWorldStmt);
        defer deleteStmt.deinit();

        deleteStmt.exec(
            .{},
            .{ .id = id },
        ) catch |err| {
            std.log.err("Failed to delete world: {}", .{err});
            return err;
        };
    }

    pub fn saveTextureScript(self: *Data, name: []const u8, textureScript: []const u8) !void {
        var insertStmt = try self.db.prepareDynamic(insertTextureScriptStmt);
        defer insertStmt.deinit();

        insertStmt.exec(
            .{},
            .{
                .name = name,
                .script = textureScript,
            },
        ) catch |err| {
            std.log.err("Failed to insert texture script: {}", .{err});
            return err;
        };
    }

    pub fn updateTextureScript(self: *Data, id: u32, name: []const u8, textureScript: []const u8) !void {
        var updateStmt = try self.db.prepareDynamic(updateTextureScriptStmt);
        defer updateStmt.deinit();

        updateStmt.exec(
            .{},
            .{
                .name = name,
                .script = textureScript,
                .id = id,
            },
        ) catch |err| {
            std.log.err("Failed to update texture script: {}", .{err});
            return err;
        };
    }

    pub fn listTextureScripts(self: *Data, data: *std.ArrayList(scriptOption)) !void {
        var listStmt = try self.db.prepareDynamic(listTextureStmt);
        defer listStmt.deinit();

        data.clearRetainingCapacity();
        const rows = listStmt.all(
            struct {
                id: u32,
                name: [21:0]u8,
            },
            self.alloc,
            .{},
            .{},
        ) catch |err| {
            std.log.err("Failed to list texture scripts: {}", .{err});
            return err;
        };
        for (rows) |row| {
            try data.append(scriptOption{
                .id = row.id,
                .name = row.name,
            });
        }
    }

    pub fn loadTextureScript(self: *Data, id: u32, data: *script) !void {
        std.debug.print("Loading texture script: {d}\n", .{id});
        var selectStmt = try self.db.prepareDynamic(selectTextureStmt);
        defer selectStmt.deinit();

        const row = selectStmt.one(
            struct {
                id: u32,
                name: [21:0]u8,
                script: [360_001:0]u8,
            },
            .{},
            .{ .id = id },
        ) catch |err| {
            std.log.err("Failed to load texture script: {}", .{err});
            return err;
        };
        if (row) |r| {
            data.id = id;
            data.name = r.name;
            data.script = r.script;
            return;
        }
        return error.Unreachable;
    }

    pub fn deleteTextureScript(self: *Data, id: u32) !void {
        var deleteStmt = try self.db.prepareDynamic(deleteTextureStmt);
        defer deleteStmt.deinit();

        deleteStmt.exec(
            .{},
            .{ .id = id },
        ) catch |err| {
            std.log.err("Failed to delete texture script: {}", .{err});
            return err;
        };
    }
};
