pub const current_schema_version: i32 = sql_schema.current_schema_version;
pub const DataErr = sql_utils.DataErr;

pub const RGBAColorTextureSize = sql_block.RGBAColorTextureSize;
pub const TextureBlobArrayStoreSize = sql_block.TextureBlobArrayStoreSize;

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

pub const playerPosition = sql_player_position.playerPosition;

pub const display_settings = sql_display_settings.display_settings;

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
            try self.saveSchema();
            return false;
        }
        const schema_version = try self.currentSchemaVersion();
        if (schema_version == 0) {
            try migrations.v2.migrate(self.allocator);
            try migrations.v3.migrate(self.allocator);
            try self.saveSchema();
        }
        if (schema_version == 2) {
            try migrations.v3.migrate(self.allocator);
            try self.updateSchema();
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
    pub fn updateSchema(self: *Data) !void {
        return sql_schema.updateSchema(self.db);
    }
    pub fn currentSchemaVersion(self: *Data) !i32 {
        return sql_schema.currentSchemaVersion(self.db);
    }

    // World
    pub fn saveWorld(self: *Data, name: []const u8, seed: i32) !void {
        return sql_world.saveWorld(self.db, name, seed);
    }
    pub fn listWorlds(self: *Data, allocator: std.mem.Allocator, data: *std.ArrayListUnmanaged(worldOption)) !void {
        return sql_world.listWorlds(self.db, allocator, data);
    }
    pub fn loadWorld(self: *Data, id: i32, data: *world) !void {
        return sql_world.loadWorld(self.db, id, data);
    }
    pub fn updateWorld(self: *Data, id: i32, name: []const u8, seed: i32) !void {
        return sql_world.updateWorld(self.db, id, name, seed);
    }
    pub fn deleteWorld(self: *Data, id: i32) !void {
        return sql_world.deleteWorld(self.db, id);
    }
    pub fn countWorlds(self: *Data) !i32 {
        return sql_world.countWorlds(self.db);
    }
    pub fn getNewestWorldId(self: *Data) !i32 {
        return sql_world.getNewestWorldId(self.db);
    }

    // Texture script
    pub fn saveTextureScript(self: *Data, name: []const u8, textureScript: []const u8) !void {
        return sql_texture_script.saveTextureScript(self.db, name, textureScript);
    }
    pub fn updateTextureScript(self: *Data, id: i32, name: []const u8, textureScript: []const u8) !void {
        return sql_texture_script.updateTextureScript(self.db, id, name, textureScript);
    }
    pub fn listTextureScripts(self: *Data, allocator: std.mem.Allocator, data: *std.ArrayListUnmanaged(scriptOption)) !void {
        return sql_texture_script.listTextureScripts(self.db, allocator, data);
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
    pub fn listChunkScripts(self: *Data, allocator: std.mem.Allocator, data: *std.ArrayListUnmanaged(sql_utils.colorScriptOption)) !void {
        return sql_chunk_script.listChunkScripts(self.db, allocator, data);
    }
    pub fn loadChunkScript(self: *Data, id: i32, data: *sql_utils.colorScript) !void {
        return sql_chunk_script.loadChunkScript(self.db, id, data);
    }
    pub fn deleteChunkScript(self: *Data, id: i32) !void {
        return sql_chunk_script.deleteChunkScript(self.db, id);
    }

    // TerrainGen script
    pub fn saveTerrainGenScript(self: *Data, name: []const u8, cScript: []const u8, color: [3]f32) !void {
        return sql_terrain_gen_script.saveTerrainGenScript(self.db, name, cScript, color);
    }
    pub fn updateTerrainGenScript(self: *Data, id: i32, name: []const u8, cScript: []const u8, color: [3]f32) !void {
        return sql_terrain_gen_script.updateTerrainGenScript(self.db, id, name, cScript, color);
    }
    pub fn listTerrainGenScripts(self: *Data, allocator: std.mem.Allocator, data: *std.ArrayListUnmanaged(sql_utils.colorScriptOption)) !void {
        return sql_terrain_gen_script.listTerrainGenScripts(self.db, allocator, data);
    }
    pub fn loadTerrainGenScript(self: *Data, id: i32, data: *sql_utils.colorScript) !void {
        return sql_terrain_gen_script.loadTerrainGenScript(self.db, id, data);
    }
    pub fn deleteTerrainGenScript(self: *Data, id: i32) !void {
        return sql_terrain_gen_script.deleteTerrainGenScript(self.db, id);
    }

    // Block
    pub fn saveBlock(self: *Data, name: []const u8, texture: []u32, transparent: bool, light_level: u8) !void {
        return sql_block.saveBlock(self.db, name, texture, transparent, light_level);
    }
    pub fn updateBlock(self: *Data, id: i32, name: []const u8, texture: []u32, transparent: bool, light_level: u8) !void {
        return sql_block.updateBlock(self.db, id, name, texture, transparent, light_level);
    }
    pub fn listBlocks(self: *Data, allocator: std.mem.Allocator, data: *std.ArrayListUnmanaged(blockOption)) !void {
        return sql_block.listBlocks(self.db, allocator, data);
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
        return sql_player_position.savePlayerPosition(self.db, world_id, pos, rot, angle);
    }
    pub fn updatePlayerPosition(
        self: *Data,
        world_id: i32,
        pos: @Vector(4, f32),
        rot: @Vector(4, f32),
        angle: f32,
    ) !void {
        return sql_player_position.updatePlayerPosition(self.db, world_id, pos, rot, angle);
    }
    pub fn loadPlayerPosition(self: *Data, world_id: i32, data: *playerPosition) !void {
        return sql_player_position.loadPlayerPosition(self.db, world_id, data);
    }
    pub fn deletePlayerPosition(self: *Data, world_id: i32) !void {
        return sql_player_position.deletePlayerPosition(self.db, world_id);
    }

    // Display settings
    pub fn saveDisplaySettings(
        self: *Data,
        fullscreen: bool,
        maximized: bool,
        decorated: bool,
        width: i32,
        height: i32,
    ) !void {
        return sql_display_settings.saveDisplaySettings(
            self.db,
            fullscreen,
            maximized,
            decorated,
            width,
            height,
        );
    }
    pub fn updateDisplaySettings(
        self: *Data,
        fullscreen: bool,
        maximized: bool,
        decorated: bool,
        width: i32,
        height: i32,
    ) !void {
        return sql_display_settings.updateDisplaySettings(
            self.db,
            fullscreen,
            maximized,
            decorated,
            width,
            height,
        );
    }
    pub fn loadDisplaySettings(self: *Data, ds: *display_settings) !void {
        return sql_display_settings.loadDisplaySettings(self.db, ds);
    }

    // World Terrain
    pub fn saveWorldTerrain(self: *Data, world_id: i32, terrain_gen_script_id: i32) !void {
        return sql_world_terrain.saveWorldTerrain(self.db, world_id, terrain_gen_script_id);
    }
    pub fn listWorldTerrains(self: *Data, data: *std.ArrayList(sql_utils.colorScriptOption)) !void {
        return sql_world_terrain.listWorldTerrains(self.db, data);
    }
    pub fn deleteWorldTerrain(self: *Data, id: i32) !void {
        return sql_world_terrain.deleteWorldTerrain(self.db, id);
    }
    pub fn deleteAllWorldTerrain(self: *Data, world_id: i32) !void {
        return sql_world_terrain.deleteAllWorldTerrain(self.db, world_id);
    }
};

const std = @import("std");
const sqlite = @import("sqlite");
const migrations = @import("migrations/migrations.zig");
const sql_world = @import("data_world.zig");
const sql_schema = @import("data_schema.zig");
const sql_texture_script = @import("data_texture_script.zig");
const sql_chunk_script = @import("data_chunk_script.zig");
const sql_terrain_gen_script = @import("data_terrain_gen_script.zig");
const sql_block = @import("data_block.zig");
const sql_chunk = @import("data_chunk.zig");
const sql_player_position = @import("data_player_position.zig");
const sql_display_settings = @import("data_display_settings.zig");
const sql_world_terrain = @import("data_world_terrain.zig");
pub const sql_utils = @import("data_sql_utils.zig");

pub const chunk_file = @import("chunk_file.zig");
