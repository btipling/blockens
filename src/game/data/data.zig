pub const current_schema_version: i32 = sql_schema.current_schema_version;
pub const DataErr = sql_utils.DataErr;

pub const RGBAColorTextureSize = sql_block.RGBAColorTextureSize;
pub const TextureBlobArrayStoreSize = sql_block.TextureBlobArrayStoreSize;

// each i32 fits into 4 u8s
pub const ChunkBlobArrayStoreSize = game_chunk.chunkSize * 4;

pub const maxBlockSizeName = 20;

pub const scriptOptionSQL = sql_utils.scriptOptionSQL;
pub const scriptSQL = sql_utils.scriptSQL;
pub const scriptOption = sql_utils.scriptOption;
pub const script = sql_utils.script;

pub const colorScriptOptionSQL = sql_utils.colorScriptOptionSQL;
pub const colorScriptSQL = sql_utils.colorScriptSQL;
pub const colorScriptOption = sql_utils.colorScriptOption;
pub const colorScript = sql_utils.colorScript;

pub const worldOptionSQL = sql_world.worldOptionSQL;
pub const worldOption = sql_world.worldOption;
pub const worldSQL = sql_world.worldSQL;
pub const world = sql_world.world;

pub const blockOptionSQL = sql_block.blockOptionSQL;
pub const blockSQL = sql_block.blockSQL;
pub const blockOption = sql_block.blockOption;
pub const block = sql_block.block;

pub const chunkDataSQL = sql_chunk.chunkDataSQL;
pub const chunkData = sql_chunk.chunkData;

pub const display_settings = struct {
    fullscreen: bool = false,
    maximized: bool = true,
    decorated: bool = false,
    width: i32 = 0,
    height: i32 = 0,
};

pub const Data = struct {
    db: sqlite.Database,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Data {
        chunk_file.initSaves(false);
        const db = try sqlite.Database.init(.{ .path = "./gamedata.db" });
        return Data{
            .db = db,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Data) void {
        self.db.deinit();
    }

    pub fn ensureDefaultWorld(self: *Data) !bool {
        chunk_file.initWorldSave(false, 1);
        if (try self.countWorlds() < 1) {
            // First time ever launchign the game.
            try sql_world.saveWorld(self.db, "default");
            try self.saveSchema();
            return false;
        }
        const schema_version = try self.currentSchemaVersion();
        if (schema_version == 0) {
            // Not the first time launching the game, migrate save.
            try migrations.v2.migrate(self.allocator);
            // There was no previous schema versioning so just insert it for the first time.
            try self.saveSchema();
        }
        return true;
    }

    // Schema
    pub fn ensureSchema(self: *Data) !void {
        return sql_schema.ensureSchema(self.db);
    }
    pub fn saveSchema(self: *Data) !void {
        return sql_schema.saveSchema(self.db);
    }
    pub fn currentSchemaVersion(self: *Data) !i32 {
        return sql_schema.currentSchemaVersion(self.db);
    }

    // World
    pub fn saveWorld(self: *Data, name: []const u8) !void {
        return sql_world.saveWorld(self.db, name);
    }
    pub fn listWorlds(self: *Data, data: *std.ArrayList(worldOption)) !void {
        return sql_world.listWorlds(self.db, data);
    }
    pub fn loadWorld(self: *Data, id: i32, data: *world) !void {
        return sql_world.loadWorld(self.db, id, data);
    }
    pub fn updateWorld(self: *Data, id: i32, name: []const u8) !void {
        return sql_world.updateWorld(self.db, id, name);
    }
    pub fn deleteWorld(self: *Data, id: i32) !void {
        return sql_world.deleteWorld(self.db, id);
    }
    pub fn countWorlds(self: *Data) !i32 {
        return sql_world.countWorlds(self.db);
    }

    // Texture script
    pub fn saveTextureScript(self: *Data, name: []const u8, textureScript: []const u8) !void {
        return sql_texture_script.saveTextureScript(self.db, name, textureScript);
    }
    pub fn updateTextureScript(self: *Data, id: i32, name: []const u8, textureScript: []const u8) !void {
        return sql_texture_script.updateTextureScript(self.db, id, name, textureScript);
    }
    pub fn listTextureScripts(self: *Data, data: *std.ArrayList(scriptOption)) !void {
        return sql_texture_script.listTextureScripts(self.db, data);
    }
    pub fn loadTextureScript(self: *Data, id: i32, data: *script) !void {
        return sql_texture_script.loadTextureScript(self.db, id, data);
    }
    pub fn deleteTextureScript(self: *Data, id: i32) !void {
        return sql_texture_script.deleteTextureScript(self.db, id);
    }

    // Chunk script
    pub fn saveChunkScript(self: *Data, name: []const u8, cScript: []const u8, color: [3]f32) !void {
        return sql_chunk_script.saveChunkScript(self.db, name, cScript, color);
    }
    pub fn updateChunkScript(self: *Data, id: i32, name: []const u8, cScript: []const u8, color: [3]f32) !void {
        return sql_chunk_script.updateChunkScript(self.db, id, name, cScript, color);
    }
    pub fn listChunkScripts(self: *Data, data: *std.ArrayList(sql_utils.colorScriptOption)) !void {
        return sql_chunk_script.listChunkScripts(self.db, data);
    }
    pub fn loadChunkScript(self: *Data, id: i32, data: *sql_utils.colorScript) !void {
        return sql_chunk_script.loadChunkScript(self.db, id, data);
    }
    pub fn deleteChunkScript(self: *Data, id: i32) !void {
        return sql_chunk_script.deleteChunkScript(self.db, id);
    }

    // Block
    pub fn saveBlock(self: *Data, name: []const u8, texture: []u32, transparent: bool, light_level: u8) !void {
        return sql_block.saveBlock(self.db, name, texture, transparent, light_level);
    }
    pub fn updateBlock(self: *Data, id: i32, name: []const u8, texture: []u32, transparent: bool, light_level: u8) !void {
        return sql_block.updateBlock(self.db, id, name, texture, transparent, light_level);
    }
    pub fn listBlocks(self: *Data, data: *std.ArrayList(blockOption)) !void {
        return sql_block.listBlocks(self.db, data);
    }
    // caller owns texture data slice
    pub fn loadBlock(self: *Data, id: i32, data: *block) !void {
        return sql_block.loadBlock(self.db, id, data);
    }
    pub fn deleteBlock(self: *Data, id: i32) !void {
        return sql_block.deleteBlock(self.db, id);
    }

    // Chunk metadata
    pub fn saveChunkMetadata(self: *Data, world_id: i32, x: i32, y: i32, z: i32, script_id: i32) !void {
        return sql_chunk.saveChunkMetadata(self.db, world_id, x, y, z, script_id);
    }
    pub fn updateChunkMetadata(self: *Data, id: i32, script_id: i32) !void {
        return sql_chunk.updateChunkMetadata(self.db, id, script_id);
    }
    pub fn getWorldDataForChunkId(self: *Data, id: i32) !sql_chunk.worldData {
        return sql_chunk.getWorldDataForChunkId(self.db, id);
    }
    pub fn loadChunkMetadata(self: *Data, world_id: i32, x: i32, y: i32, z: i32, data: *chunkData) !void {
        return sql_chunk.loadChunkMetadata(self.db, world_id, x, y, z, data);
    }
    pub fn deleteChunkData(self: *Data, world_id: i32) !void {
        return sql_chunk.deleteChunkData(self.db, world_id);
    }
    pub fn deleteChunkDataById(self: *Data, id: i32, world_id: i32) !void {
        return sql_chunk.deleteChunkDataById(self.db, id, world_id);
    }

    // Player Position

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

        return sql_utils.DataErr.NotFound;
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

    pub fn saveDisplaySettings(
        self: *Data,
        fullscreen: bool,
        maximized: bool,
        decorated: bool,
        width: i32,
        height: i32,
    ) !void {
        var insert_stmt = try self.db.prepare(
            struct {
                fullscreen: i32,
                maximized: i32,
                decorated: i32,
                width: i32,
                height: i32,
            },
            void,
            insert_display_settings_stmt,
        );
        defer insert_stmt.deinit();

        const fs: i32 = if (fullscreen) (1) else 0;
        const mx: i32 = if (maximized) (1) else 0;
        const dr: i32 = if (decorated) (1) else 0;
        insert_stmt.exec(
            .{
                .fullscreen = fs,
                .maximized = mx,
                .decorated = dr,
                .width = width,
                .height = height,
            },
        ) catch |err| {
            std.log.err("Failed to insert display settings: {}", .{err});
            return err;
        };
    }

    pub fn updateDisplaySettings(
        self: *Data,
        fullscreen: bool,
        maximized: bool,
        decorated: bool,
        width: i32,
        height: i32,
    ) !void {
        var update_stmt = try self.db.prepare(
            struct {
                id: i32,
                fullscreen: i32,
                maximized: i32,
                decorated: i32,
                width: i32,
                height: i32,
            },
            void,
            update_display_settings_stmt,
        );
        defer update_stmt.deinit();

        const fs: i32 = if (fullscreen) (1) else 0;
        const mx: i32 = if (maximized) (1) else 0;
        const dr: i32 = if (decorated) (1) else 0;
        update_stmt.exec(
            .{
                .id = 1,
                .fullscreen = fs,
                .maximized = mx,
                .decorated = dr,
                .width = width,
                .height = height,
            },
        ) catch |err| {
            std.log.err("Failed to update block: {}", .{err});
            return err;
        };
    }

    pub fn loadDisplaySettings(self: *Data, ds: *display_settings) !void {
        var select_stmt = try self.db.prepare(
            struct {
                id: i32,
            },
            struct {
                fullscreen: i32,
                maximized: i32,
                decorated: i32,
                width: i32,
                height: i32,
            },
            select_display_settings_stmt,
        );
        defer select_stmt.deinit();

        {
            try select_stmt.bind(.{ .id = 1 });
            defer select_stmt.reset();

            while (try select_stmt.step()) |r| {
                ds.fullscreen = r.fullscreen == 1;
                ds.maximized = r.maximized == 1;
                ds.decorated = r.decorated == 1;
                ds.width = r.width;
                ds.height = r.height;
                return;
            }
        }

        return sql_utils.DataErr.NotFound;
    }
};

const insert_player_pos_stmt = @embedFile("./sql/v2/player_position/insert.sql");
const update_player_pos_stmt = @embedFile("./sql/v2/player_position/update.sql");
const select_player_pos_stmt = @embedFile("./sql/v2/player_position/select.sql");
const delete_player_pos_stmt = @embedFile("./sql/v2/player_position/delete.sql");

const insert_display_settings_stmt = @embedFile("./sql/v2/display_settings/insert.sql");
const update_display_settings_stmt = @embedFile("./sql/v2/display_settings/update.sql");
const select_display_settings_stmt = @embedFile("./sql/v2/display_settings/select.sql");
const list_display_settings_stmt = @embedFile("./sql/v2/display_settings/list.sql");
const delete_display_settings_stmt = @embedFile("./sql/v2/display_settings/delete.sql");

const std = @import("std");
const sqlite = @import("sqlite");
const migrations = @import("migrations/migrations.zig");
const sql_world = @import("data_world.zig");
const sql_schema = @import("data_schema.zig");
const sql_texture_script = @import("data_texture_script.zig");
const sql_chunk_script = @import("data_chunk_script.zig");
const sql_block = @import("data_block.zig");
const sql_chunk = @import("data_chunk.zig");
pub const sql_utils = @import("data_sql_utils.zig");
const game_block = @import("../block/block.zig");
const game_chunk = game_block.chunk;
const chunk_big = game_chunk.big;

pub const chunk_file = @import("chunk_file.zig");
