const std = @import("std");
const sqlite = @import("sqlite");

const createWorldTable = @embedFile("./sql/world/create.sql");
const insertWorldStmt = @embedFile("./sql/world/insert.sql");
const selectWorldByNameStmt = @embedFile("./sql/world/select_by_name.sql");
const selectWorldByIdStmt = @embedFile("./sql/world/select_by_id.sql");
const listWorldStmt = @embedFile("./sql/world/list.sql");
const updateWorldStmt = @embedFile("./sql/world/update.sql");
const deleteWorldStmt = @embedFile("./sql/world/delete.sql");
const countWorldsStmt = @embedFile("./sql/world/count_worlds.sql");

const createTextureScriptTable = @embedFile("./sql/texture_script/create.sql");
const insertTextureScriptStmt = @embedFile("./sql/texture_script/insert.sql");
const updateTextureScriptStmt = @embedFile("./sql/texture_script/update.sql");
const selectTextureStmt = @embedFile("./sql/texture_script/select.sql");
const listTextureStmt = @embedFile("./sql/texture_script/list.sql");
const deleteTextureStmt = @embedFile("./sql/texture_script/delete.sql");

const createChunkScriptTable = @embedFile("./sql/chunk_script/create.sql");
const insertChunkScriptStmt = @embedFile("./sql/chunk_script/insert.sql");
const updateChunkScriptStmt = @embedFile("./sql/chunk_script/update.sql");
const selectChunkStmt = @embedFile("./sql/chunk_script/select.sql");
const listChunkStmt = @embedFile("./sql/chunk_script/list.sql");
const deleteChunkStmt = @embedFile("./sql/chunk_script/delete.sql");

const createBlockTable = @embedFile("./sql/block/create.sql");
const insertBlockStmt = @embedFile("./sql/block/insert.sql");
const updateBlockStmt = @embedFile("./sql/block/update.sql");
const selectBlockStmt = @embedFile("./sql/block/select.sql");
const listBlockStmt = @embedFile("./sql/block/list.sql");
const deleteBlockStmt = @embedFile("./sql/block/delete.sql");

const createChunkDataTable = @embedFile("./sql/chunk/create.sql");
const insertChunkDataStmt = @embedFile("./sql/chunk/insert.sql");
const updateChunkDataStmt = @embedFile("./sql/chunk/update.sql");
const selectChunkDataByIDStmt = @embedFile("./sql/chunk/select_by_id.sql");
const selectChunkDataByCoordsStmt = @embedFile("./sql/chunk/select_by_coords.sql");
const listChunkDataStmt = @embedFile("./sql/chunk/list.sql");
const deleteChunkDataStmt = @embedFile("./sql/chunk/delete.sql");
const delete_chunk_data_by_id_stmt = @embedFile("./sql/chunk/delete_by_id.sql");

pub const DataErr = error{
    NotFound,
};

pub const RGBAColorTextureSize = 3 * 16 * 16; // 768
// 768 i32s fit into 3072 u8s
pub const TextureBlobArrayStoreSize = 3072;

pub const chunkDim = 64;
pub const chunkSize = chunkDim * chunkDim * chunkDim;
// each i32 fits into 4 u8s
pub const ChunkBlobArrayStoreSize = chunkSize * 4;

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

pub const chunkScriptOptionSQL = struct {
    id: i32,
    name: sqlite.Text,
    color: i32,
};

pub const chunkScriptSQL = struct {
    id: i32,
    name: sqlite.Text,
    script: sqlite.Text,
    color: i32,
};

pub const chunkScriptOption = struct {
    id: i32,
    name: [21:0]u8,
    color: [3]f32,
};

pub const chunkScript = struct {
    id: i32,
    name: [21]u8,
    script: [360_001]u8,
    color: [3]f32,
};

pub const chunkDataSQL = struct {
    id: i32,
    world_id: i32,
    x: i32,
    y: i32,
    z: i32,
    scriptId: i32,
    voxels: sqlite.Blob,
};

pub const chunkData = struct {
    id: i32 = 0,
    world_id: i32 = 0,
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    scriptId: i32 = 0,
    voxels: []u32 = undefined,
};

pub const Data = struct {
    db: sqlite.Database,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Data {
        const db = try sqlite.Database.init(.{ .path = "./gamedata.db" });
        return Data{
            .db = db,
            .allocator = allocator,
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
            createChunkScriptTable,
            createChunkDataTable,
            create_player_pos_table,
        };
        for (createTableQueries) |query| {
            self.db.exec(query, .{}) catch |err| {
                std.log.err("Failed to create schema: {}", .{err});
                return err;
            };
        }
    }

    pub fn ensureDefaultWorld(self: *Data) !bool {
        if (try self.countWorlds() < 1) {
            try saveWorld(self, "default");
            return false;
        }
        return true;
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

    fn sqlNameToArray(name: sqlite.Text) [21:0]u8 {
        var n: [21:0]u8 = [_:0]u8{0} ** 21;
        for (name.data, 0..) |c, i| {
            n[i] = c;
            if (c == 0) {
                break;
            }
        }
        return n;
    }

    fn colorToInteger3(color: [3]f32) i32 {
        const c: [4]f32 = .{ color[0], color[1], color[2], 1.0 };
        return colorToInteger4(c);
    }

    fn integerToColor3(color: i32) [3]f32 {
        const c: [4]f32 = integerToColor4(color);
        return .{ c[0], c[1], c[2] };
    }

    fn colorToInteger4(color: [4]f32) i32 {
        const a = @as(i32, @intFromFloat(color[3] * 255.0));
        const b = @as(i32, @intFromFloat(color[2] * 255.0));
        const g = @as(i32, @intFromFloat(color[1] * 255.0));
        const r = @as(i32, @intFromFloat(color[0] * 255.0));
        const rv: i32 = a << 24 | b << 16 | g << 8 | r;
        return rv;
    }

    fn integerToColor4(color: i32) [4]f32 {
        const a = @as(f32, @floatFromInt(color >> 24 & 0xFF)) / 255.0;
        const b = @as(f32, @floatFromInt(color >> 16 & 0xFF)) / 255.0;
        const g = @as(f32, @floatFromInt(color >> 8 & 0xFF)) / 255.0;
        const r = @as(f32, @floatFromInt(color & 0xFF)) / 255.0;
        return .{ r, g, b, a };
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

        deleteStmt.exec(.{ .id = id }) catch |err| {
            std.log.err("Failed to delete world: {}", .{err});
            return err;
        };
    }

    pub fn countWorlds(self: *Data) !i32 {
        var countStmt = try self.db.prepare(
            struct {
                id: i32,
            },
            struct {
                count: i32,
            },
            countWorldsStmt,
        );
        defer countStmt.deinit();

        try countStmt.bind(.{ .id = 0 });
        defer countStmt.reset();
        while (try countStmt.step()) |r| {
            return r.count;
        }

        return 0;
    }

    fn sqlTextToScript(text: sqlite.Text) [360_001]u8 {
        var n: [360_001]u8 = [_]u8{0} ** 360_001;
        for (text.data, 0..) |c, i| {
            n[i] = c;
        }
        return n;
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

            while (try listStmt.step()) |r| {
                try data.append(
                    scriptOption{
                        .id = r.id,
                        .name = sqlNameToArray(r.name),
                    },
                );
            }
        }
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

    pub fn saveChunkScript(self: *Data, name: []const u8, cScript: []const u8, color: [3]f32) !void {
        var insertStmt = try self.db.prepare(
            struct {
                name: sqlite.Text,
                script: sqlite.Text,
                color: i32,
            },
            void,
            insertChunkScriptStmt,
        );
        defer insertStmt.deinit();

        insertStmt.exec(
            .{
                .name = sqlite.text(name),
                .script = sqlite.text(cScript),
                .color = colorToInteger3(color),
            },
        ) catch |err| {
            std.log.err("Failed to insert script: {}", .{err});
            return err;
        };
    }

    pub fn updateChunkScript(self: *Data, id: i32, name: []const u8, cScript: []const u8, color: [3]f32) !void {
        var updateStmt = try self.db.prepare(
            chunkScriptSQL,
            void,
            updateChunkScriptStmt,
        );
        defer updateStmt.deinit();

        updateStmt.exec(
            .{
                .id = id,
                .name = sqlite.text(name),
                .script = sqlite.text(cScript),
                .color = colorToInteger3(color),
            },
        ) catch |err| {
            std.log.err("Failed to update script: {}", .{err});
            return err;
        };
    }

    pub fn listChunkScripts(self: *Data, data: *std.ArrayList(chunkScriptOption)) !void {
        var listStmt = try self.db.prepare(
            struct {},
            chunkScriptOptionSQL,
            listChunkStmt,
        );
        defer listStmt.deinit();

        data.clearRetainingCapacity();
        {
            try listStmt.bind(.{});
            defer listStmt.reset();

            while (try listStmt.step()) |r| {
                try data.append(
                    chunkScriptOption{
                        .id = r.id,
                        .name = sqlNameToArray(r.name),
                        .color = integerToColor3(r.color),
                    },
                );
            }
        }
    }

    pub fn loadChunkScript(self: *Data, id: i32, data: *chunkScript) !void {
        var selectStmt = try self.db.prepare(
            struct {
                id: i32,
            },
            chunkScriptSQL,
            selectChunkStmt,
        );
        defer selectStmt.deinit();

        {
            try selectStmt.bind(.{ .id = id });
            defer selectStmt.reset();

            while (try selectStmt.step()) |r| {
                data.id = r.id;
                data.name = sqlNameToArray(r.name);
                data.script = sqlTextToScript(r.script);
                data.color = integerToColor3(r.color);
                return;
            }
        }

        return DataErr.NotFound;
    }

    pub fn deleteChunkScript(self: *Data, id: i32) !void {
        var deleteStmt = try self.db.prepare(
            struct {
                id: i32,
            },
            void,
            deleteChunkStmt,
        );

        deleteStmt.exec(
            .{ .id = id },
        ) catch |err| {
            std.log.err("Failed to delete chunk script: {}", .{err});
            return err;
        };
    }

    // block crud:
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

    fn blobToTexture(self: *Data, blob: sqlite.Blob) ![]u32 {
        var texture: [RGBAColorTextureSize]u32 = undefined;
        for (texture, 0..) |_, i| {
            const offset = i * 4;
            const a = @as(u32, @intCast(blob.data[offset]));
            const b = @as(u32, @intCast(blob.data[offset + 1]));
            const g = @as(u32, @intCast(blob.data[offset + 2]));
            const r = @as(u32, @intCast(blob.data[offset + 3]));
            texture[i] = a << 24 | b << 16 | g << 8 | r;
        }

        const rv: []u32 = try self.allocator.alloc(u32, texture.len);
        @memcpy(rv, &texture);
        return rv;
    }

    pub fn saveBlock(self: *Data, name: []const u8, texture: []u32, transparent: bool, light_level: u8) !void {
        var insertStmt = try self.db.prepare(
            struct {
                name: sqlite.Text,
                texture: sqlite.Blob,
                light_level: i32,
                transparent: i32,
            },
            void,
            insertBlockStmt,
        );
        defer insertStmt.deinit();

        var t = textureToBlob(texture);
        var t_int: i32 = 0;
        if (transparent) t_int = 1;
        insertStmt.exec(
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

    pub fn updateBlock(self: *Data, id: i32, name: []const u8, texture: []u32, transparent: bool, light_level: u8) !void {
        var updateStmt = try self.db.prepare(
            struct {
                id: i32,
                name: sqlite.Text,
                texture: sqlite.Blob,
                light_level: i32,
                transparent: i32,
            },
            void,
            updateBlockStmt,
        );
        defer updateStmt.deinit();

        var t = textureToBlob(texture);
        var t_int: i32 = 0;
        if (transparent) t_int = 1;
        updateStmt.exec(
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
                        .id = @intCast(row.id),
                        .name = sqlNameToArray(row.name),
                    },
                );
            }
        }
    }

    // caller owns texture data slice
    pub fn loadBlock(self: *Data, id: i32, data: *block) !void {
        var selectStmt = try self.db.prepare(
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
            selectBlockStmt,
        );
        defer selectStmt.deinit();

        {
            try selectStmt.bind(.{ .id = id });
            defer selectStmt.reset();

            while (try selectStmt.step()) |r| {
                data.id = @intCast(r.id);
                data.name = sqlNameToArray(r.name);
                data.texture = try self.blobToTexture(r.texture);
                data.light_level = @intCast(r.light_level);
                data.transparent = r.transparent == 1;
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

    // chunk crud:
    fn chunkToBlob(chunk: []u32) [ChunkBlobArrayStoreSize]u8 {
        var blob: [ChunkBlobArrayStoreSize]u8 = undefined;
        for (chunk, 0..) |t, i| {
            const u = @as(u32, @bitCast(t));
            const offset = i * 4;
            const a = @as(u8, @truncate(u >> 24));
            const b = @as(u8, @truncate(u >> 16));
            const c = @as(u8, @truncate(u >> 8));
            const d = @as(u8, @truncate(u));
            blob[offset] = a;
            blob[offset + 1] = b;
            blob[offset + 2] = c;
            blob[offset + 3] = d;
        }
        return blob;
    }

    fn blobToChunk(self: *Data, blob: sqlite.Blob) []u32 {
        var chunk: [chunkSize]u32 = undefined;
        for (chunk, 0..) |_, i| {
            const offset = i * 4;
            const a = @as(u32, @intCast(blob.data[offset]));
            const b = @as(u32, @intCast(blob.data[offset + 1]));
            const c = @as(u32, @intCast(blob.data[offset + 2]));
            const d = @as(u32, @intCast(blob.data[offset + 3]));
            const cd: u32 = a << 24 | b << 16 | c << 8 | d;
            chunk[i] = @bitCast(cd);
        }
        const rv: []u32 = self.allocator.alloc(u32, chunk.len) catch unreachable;
        @memcpy(rv, &chunk);
        return rv;
    }

    pub fn saveChunkData(
        self: *Data,
        world_id: i32,
        x: i32,
        y: i32,
        z: i32,
        scriptId: i32,
        voxels: []u32,
    ) !void {
        var insertStmt = try self.db.prepare(
            struct {
                world_id: i32,
                x: i32,
                y: i32,
                z: i32,
                script_id: i32,
                voxels: sqlite.Blob,
            },
            void,
            insertChunkDataStmt,
        );
        defer insertStmt.deinit();

        var t = chunkToBlob(voxels);
        insertStmt.exec(
            .{
                .world_id = world_id,
                .x = x,
                .y = y,
                .z = z,
                .script_id = scriptId,
                .voxels = sqlite.blob(&t),
            },
        ) catch |err| {
            std.log.err("Failed to insert chunkdata: {}", .{err});
            return err;
        };
    }

    pub fn updateChunkData(self: *Data, id: i32, script_id: i32, voxels: []u32) !void {
        var updateStmt = try self.db.prepare(
            struct {
                id: i32,
                script_id: i32,
                voxels: sqlite.Blob,
            },
            void,
            updateChunkDataStmt,
        );
        defer updateStmt.deinit();

        var c = chunkToBlob(voxels);
        updateStmt.exec(
            .{
                .id = id,
                .script_id = script_id,
                .voxels = sqlite.blob(&c),
            },
        ) catch |err| {
            std.log.err("Failed to update chunkdata: {}", .{err});
            return err;
        };
    }

    pub fn loadChunkData(self: *Data, world_id: i32, x: i32, y: i32, z: i32, data: *chunkData) !void {
        var selectStmt = try self.db.prepare(
            struct {
                x: i32,
                y: i32,
                z: i32,
                world_id: i32,
            },
            struct {
                id: i32,
                world_id: i32,
                x: i32,
                y: i32,
                z: i32,
                script_id: i32,
                voxels: sqlite.Blob,
            },
            selectChunkDataByCoordsStmt,
        );
        defer selectStmt.deinit();

        {
            try selectStmt.bind(.{
                .x = x,
                .y = y,
                .z = z,
                .world_id = world_id,
            });
            defer selectStmt.reset();

            while (try selectStmt.step()) |r| {
                data.id = r.id;
                data.world_id = r.world_id;
                data.x = r.x;
                data.y = r.y;
                data.z = r.z;
                data.scriptId = r.script_id;
                data.voxels = self.blobToChunk(r.voxels);
                return;
            }
        }

        return DataErr.NotFound;
    }

    pub fn deleteChunkData(self: *Data, world_id: i32) !void {
        var deleteStmt = try self.db.prepare(
            struct {
                world_id: i32,
            },
            void,
            deleteChunkDataStmt,
        );

        deleteStmt.exec(
            .{ .world_id = world_id },
        ) catch |err| {
            std.log.err("Failed to delete chunkdata: {}", .{err});
            return err;
        };
    }

    pub fn deleteChunkDataById(self: *Data, id: i32, world_id: i32) !void {
        var deleteStmt = try self.db.prepare(
            struct {
                id: i32,
                world_id: i32,
            },
            void,
            delete_chunk_data_by_id_stmt,
        );

        deleteStmt.exec(
            .{ .id = id, .world_id = world_id },
        ) catch |err| {
            std.log.err("Failed to delete data by id: {}", .{err});
            return err;
        };
    }

    // Player Position

    const create_player_pos_table = @embedFile("./sql/player_position/create.sql");
    const insert_player_pos_stmt = @embedFile("./sql/player_position/insert.sql");
    const update_player_pos_stmt = @embedFile("./sql/player_position/update.sql");
    const select_player_pos_stmt = @embedFile("./sql/player_position/select.sql");
    const delete_player_pos_stmt = @embedFile("./sql/player_position/delete.sql");

    pub fn savePlayerPosition(
        self: *Data,
        world_id: i32,
        pos: @Vector(4, f32),
        rot: @Vector(4, f32),
        angle: f32,
    ) !void {
        var insert_stmt = try self.db.prepare(
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
        self: *Data,
        world_id: i32,
        pos: @Vector(4, f32),
        rot: @Vector(4, f32),
        angle: f32,
    ) !void {
        var update_stmt = try self.db.prepare(
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

    pub fn loadPlayerPosition(self: *Data, world_id: i32, data: *playerPosition) !void {
        var select_stmt = try self.db.prepare(
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

        return DataErr.NotFound;
    }

    pub fn deletePlayerPosition(self: *Data, world_id: i32) !void {
        var delete_stmt = try self.db.prepare(
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
};
