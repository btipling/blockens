const std = @import("std");
const sqlite = @import("sqlite");
const gl = @import("zopengl");

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

const createBlockTable = @embedFile("./sql/block/create.sql");
const insertBlockStmt = @embedFile("./sql/block/insert.sql");
const updateBlockStmt = @embedFile("./sql/block/update.sql");
const selectBlockStmt = @embedFile("./sql/block/select.sql");
const listBlockStmt = @embedFile("./sql/block/list.sql");
const deleteBlockStmt = @embedFile("./sql/block/delete.sql");

pub const RGBAColorTextureSize = 3 * 16 * 16; // 768
// 768 i32s fit into 3072 u8s
pub const TextureBlobArrayStoreSize = 3072;

pub const maxBlockSizeName = 20;

pub const scriptOptionSQL = struct {
    id: i32,
    name: sqlite.Text,
};

pub const scriptSQL = struct {
    id: i32,
    name: sqlite.Text,
    script: sqlite.Text,
};

pub const scriptOption = struct {
    id: i32,
    name: [21]u8,
};

pub const script = struct {
    id: i32,
    name: [21]u8,
    script: [360_001]u8,
};

pub const worldOptionSQL = struct {
    id: i32,
    name: sqlite.Text,
};

pub const worldSQL = struct {
    id: i32,
    name: sqlite.Text,
};

pub const worldOption = struct {
    id: i32,
    name: [21]u8,
};

pub const world = struct {
    id: i32,
    name: [21]u8,
};

pub const blockOptionSQL = struct {
    id: i32,
    name: sqlite.Text,
};

pub const blockSQL = struct {
    id: i32,
    name: sqlite.Text,
    texture: sqlite.Blob,
};

pub const blockOption = struct {
    id: i32,
    name: [21]u8,
};

pub const block = struct {
    id: i32,
    name: [21]u8,
    texture: [RGBAColorTextureSize]gl.Uint,
};

pub const Data = struct {
    db: sqlite.Database,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !Data {
        const db = try sqlite.Database.init(.{ .path = "./gamedata.db" });
        return Data{
            .db = db,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Data) void {
        self.db.deinit();
    }

    pub fn ensureSchema(self: *Data) !void {
        const createTableQueries = [_][]const u8{
            createWorldTable,
            createTextureScriptTable,
            createBlockTable,
        };
        for (createTableQueries) |query| {
            self.db.exec(query, .{}) catch |err| {
                std.log.err("Failed to create schema: {}", .{err});
                return err;
            };
        }
    }

    pub fn ensureDefaultWorld(self: *Data) !void {
        // query for the default world
        var selectStmt = try self.db.prepare(
            struct {
                name: sqlite.Text,
            },
            struct {
                name: sqlite.Text,
            },
            selectWorldByNameStmt,
        );
        defer selectStmt.deinit();

        {
            try selectStmt.bind(.{ .name = sqlite.text("default") });
            defer selectStmt.reset();

            while (try selectStmt.step()) |r| {
                std.debug.print("Found default world: {s}\n", .{r.name.data});
                return;
            }
        }
        try saveWorld(self, "default");
    }

    pub fn saveWorld(self: *Data, name: []const u8) !void {
        var insertStmt = try self.db.prepare(
            struct {
                name: sqlite.Text,
            },
            void,
            insertWorldStmt,
        );
        defer insertStmt.deinit();

        insertStmt.exec(
            .{ .name = sqlite.text(name) },
        ) catch |err| {
            std.log.err("Failed to insert world: {}", .{err});
            return err;
        };
    }

    fn sqlNameToArray(name: sqlite.Text) [21]u8 {
        var n: [21]u8 = [_]u8{0} ** 21;
        for (name.data, 0..) |c, i| {
            n[i] = c;
        }
        return n;
    }

    pub fn listWorlds(self: *Data, data: *std.ArrayList(worldOption)) !void {
        var listStmt = try self.db.prepare(
            struct {},
            worldOptionSQL,
            listWorldStmt,
        );
        defer listStmt.deinit();

        data.clearRetainingCapacity();
        {
            try listStmt.bind(.{});
            defer listStmt.reset();

            while (try listStmt.step()) |row| {
                try data.append(
                    worldOption{
                        .id = row.id,
                        .name = sqlNameToArray(row.name),
                    },
                );
            }
        }
    }

    pub fn loadWorld(self: *Data, id: i32, data: *world) !void {
        std.debug.print("Loading world: {d}\n", .{id});
        var selectStmt = try self.db.prepare(
            struct {
                id: i32,
            },
            worldSQL,
            selectWorldByIdStmt,
        );
        defer selectStmt.deinit();

        {
            try selectStmt.bind(.{ .id = id });
            defer selectStmt.reset();

            while (try selectStmt.step()) |r| {
                std.debug.print("Found world: {s}\n", .{r.name.data});
                data.id = r.id;
                data.name = sqlNameToArray(r.name);
                return;
            }
        }

        return error.Unreachable;
    }

    pub fn updateWorld(self: *Data, id: i32, name: []const u8) !void {
        var updateStmt = try self.db.prepare(
            worldSQL,
            void,
            updateWorldStmt,
        );
        defer updateStmt.deinit();

        updateStmt.exec(
            .{
                .id = id,
                .name = sqlite.text(name),
            },
        ) catch |err| {
            std.log.err("Failed to update world: {}", .{err});
            return err;
        };
    }

    pub fn deleteWorld(self: *Data, id: i32) !void {
        var deleteStmt = try self.db.prepare(
            struct {
                id: i32,
            },
            void,
            deleteWorldStmt,
        );

        deleteStmt.exec(
            .{ .id = id },
        ) catch |err| {
            std.log.err("Failed to delete world: {}", .{err});
            return err;
        };
    }

    pub fn saveTextureScript(self: *Data, name: []const u8, textureScript: []const u8) !void {
        var insertStmt = try self.db.prepare(
            struct {
                name: sqlite.Text,
                script: sqlite.Text,
            },
            void,
            insertTextureScriptStmt,
        );
        defer insertStmt.deinit();

        insertStmt.exec(
            .{
                .name = sqlite.text(name),
                .script = sqlite.text(textureScript),
            },
        ) catch |err| {
            std.log.err("Failed to insert script: {}", .{err});
            return err;
        };
    }

    pub fn updateTextureScript(self: *Data, id: i32, name: []const u8, textureScript: []const u8) !void {
        var updateStmt = try self.db.prepare(
            scriptSQL,
            void,
            updateTextureScriptStmt,
        );
        defer updateStmt.deinit();

        updateStmt.exec(
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

    pub fn listTextureScripts(self: *Data, data: *std.ArrayList(scriptOption)) !void {
        var listStmt = try self.db.prepare(
            struct {},
            scriptOptionSQL,
            listTextureStmt,
        );
        defer listStmt.deinit();

        data.clearRetainingCapacity();
        {
            try listStmt.bind(.{});
            defer listStmt.reset();

            while (try listStmt.step()) |row| {
                try data.append(
                    scriptOption{
                        .id = row.id,
                        .name = sqlNameToArray(row.name),
                    },
                );
            }
        }
    }

    fn sqlTextToScript(text: sqlite.Text) [360_001]u8 {
        var n: [360_001]u8 = [_]u8{0} ** 360_001;
        for (text.data, 0..) |c, i| {
            n[i] = c;
        }
        return n;
    }

    pub fn loadTextureScript(self: *Data, id: i32, data: *script) !void {
        var selectStmt = try self.db.prepare(
            struct {
                id: i32,
            },
            scriptSQL,
            selectTextureStmt,
        );
        defer selectStmt.deinit();

        {
            try selectStmt.bind(.{ .id = id });
            defer selectStmt.reset();

            while (try selectStmt.step()) |r| {
                data.id = r.id;
                data.name = sqlNameToArray(r.name);
                data.script = sqlTextToScript(r.script);
                return;
            }
        }

        return error.Unreachable;
    }

    pub fn deleteTextureScript(self: *Data, id: i32) !void {
        var deleteStmt = try self.db.prepare(
            struct {
                id: i32,
            },
            void,
            deleteTextureStmt,
        );

        deleteStmt.exec(
            .{ .id = id },
        ) catch |err| {
            std.log.err("Failed to delete texture script: {}", .{err});
            return err;
        };
    }

    // block crud:
    fn textureToBlob(texture: [RGBAColorTextureSize]gl.Uint) [TextureBlobArrayStoreSize]u8 {
        var blob: [TextureBlobArrayStoreSize]u8 = undefined;
        for (texture, 0..) |t, i| {
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

    fn blobToTexture(blob: sqlite.Blob) [RGBAColorTextureSize]gl.Uint {
        var texture: [RGBAColorTextureSize]gl.Uint = undefined;
        for (texture, 0..) |_, i| {
            const offset = i * 4;
            const a = @as(gl.Uint, @intCast(blob.data[offset]));
            const b = @as(gl.Uint, @intCast(blob.data[offset + 1]));
            const g = @as(gl.Uint, @intCast(blob.data[offset + 2]));
            const r = @as(gl.Uint, @intCast(blob.data[offset + 3]));
            texture[i] = a << 24 | b << 16 | g << 8 | r;
        }
        return texture;
    }

    pub fn saveBlock(self: *Data, name: []const u8, texture: [RGBAColorTextureSize]gl.Uint) !void {
        var insertStmt = try self.db.prepare(
            struct {
                name: sqlite.Text,
                texture: sqlite.Blob,
            },
            void,
            insertBlockStmt,
        );
        defer insertStmt.deinit();

        var t = textureToBlob(texture);
        insertStmt.exec(
            .{
                .name = sqlite.text(name),
                .texture = sqlite.blob(&t),
            },
        ) catch |err| {
            std.log.err("Failed to insert block: {}", .{err});
            return err;
        };
    }

    pub fn updateBlock(self: *Data, id: i32, name: []const u8, texture: [RGBAColorTextureSize]gl.Uint) !void {
        var updateStmt = try self.db.prepare(
            struct {
                id: i32,
                name: sqlite.Text,
                texture: sqlite.Blob,
            },
            void,
            updateBlockStmt,
        );
        defer updateStmt.deinit();

        var t = textureToBlob(texture);
        updateStmt.exec(
            .{
                .id = id,
                .name = sqlite.text(name),
                .texture = sqlite.blob(&t),
            },
        ) catch |err| {
            std.log.err("Failed to update block: {}", .{err});
            return err;
        };
    }

    pub fn listBlocks(self: *Data, data: *std.ArrayList(blockOption)) !void {
        var listStmt = try self.db.prepare(
            struct {},
            blockOptionSQL,
            listBlockStmt,
        );
        defer listStmt.deinit();

        data.clearRetainingCapacity();
        {
            try listStmt.bind(.{});
            defer listStmt.reset();

            while (try listStmt.step()) |row| {
                try data.append(
                    blockOption{
                        .id = row.id,
                        .name = sqlNameToArray(row.name),
                    },
                );
            }
        }
    }

    pub fn loadBlock(self: *Data, id: i32, data: *block) !void {
        var selectStmt = try self.db.prepare(
            struct {
                id: i32,
            },
            struct {
                id: i32,
                name: sqlite.Text,
                texture: sqlite.Blob,
            },
            selectBlockStmt,
        );
        defer selectStmt.deinit();

        {
            try selectStmt.bind(.{ .id = id });
            defer selectStmt.reset();

            while (try selectStmt.step()) |r| {
                data.id = r.id;
                data.name = sqlNameToArray(r.name);
                data.texture = blobToTexture(r.texture);
                return;
            }
        }

        return error.Unreachable;
    }

    pub fn deleteBlock(self: *Data, id: i32) !void {
        var deleteStmt = try self.db.prepare(
            struct {
                id: i32,
            },
            void,
            deleteBlockStmt,
        );

        deleteStmt.exec(
            .{ .id = id },
        ) catch |err| {
            std.log.err("Failed to delete block: {}", .{err});
            return err;
        };
    }
};
