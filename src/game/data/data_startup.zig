const requiredBlock = struct {
    id: i32,
    texture_name: []const u8,
    block_name: []const u8,
    texture_script: []const u8,
    transparent: bool = false,
    emits_light: bool = false,
};

const requiredChunkScript = struct {
    id: i32,
    script_name: []const u8,
    chunk_script: []const u8,
    color: [3]f32,
};

const requiredTerrainScript = struct {
    id: i32,
    script_name: []const u8,
    terrain_script: []const u8,
    color: [3]f32,
};

const required_blocks = [_]requiredBlock{
    .{
        .id = 1,
        .texture_name = "stone",
        .block_name = "stone",
        .texture_script = @embedFile("../script/lua/gen_stone_texture.lua"),
    },
    .{
        .id = 2,
        .texture_name = "grass",
        .block_name = "grass",
        .texture_script = @embedFile("../script/lua/gen_grass_texture.lua"),
    },
    .{
        .id = 3,
        .texture_name = "dirt",
        .block_name = "dirt",
        .texture_script = @embedFile("../script/lua/gen_dirt_texture.lua"),
    },
    .{
        .id = 4,
        .texture_name = "lava",
        .block_name = "lava",
        .texture_script = @embedFile("../script/lua/gen_lava_texture.lua"),
        .emits_light = true,
    },
    .{
        .id = 5,
        .texture_name = "water",
        .block_name = "water",
        .texture_script = @embedFile("../script/lua/gen_water_texture.lua"),
    },
};

const required_chunks = [_]requiredChunkScript{
    .{
        .id = 1,
        .script_name = "surface chunk",
        .chunk_script = @embedFile("../script/lua/chunk_gen_surface.lua"),
        .color = .{ 0, 0, 0 },
    },
};

const required_terrain_scripts = [_]requiredTerrainScript{
    .{
        .id = 1,
        .script_name = "default",
        .terrain_script = @embedFile("../script/lua/desc_gen_default.lua"),
        .color = .{ 0, 0, 0 },
    },
};

pub fn generateRequiredData() void {
    generateRequiredBlocks();
    generateRequiredChunks();
    generateRequiredTerrainScripts();
}

pub fn generateRequiredBlocks() void {
    for (required_blocks) |rb| {
        generateRequiredBlock(rb);
    }
}

fn generateRequiredBlock(rb: requiredBlock) void {
    var dirt_texture_script = std.mem.zeroes([script.maxLuaScriptSize]u8);
    for (rb.texture_script, 0..) |c, i| {
        dirt_texture_script[i] = c;
    }
    const texture = game.state.script.evalTextureFunc(dirt_texture_script) catch @panic("lua error") orelse @panic("lua error");
    defer game.state.allocator.free(texture);
    game.state.db.saveTextureScript(
        rb.texture_name,
        dirt_texture_script[0..],
    ) catch @panic("db error");
    const light_level: u8 = if (rb.emits_light) 1 else 0;
    game.state.db.saveBlock(
        rb.block_name,
        @ptrCast(texture),
        rb.transparent,
        light_level,
    ) catch @panic("db error");
}

pub fn generateRequiredChunks() void {
    for (required_chunks) |rc| {
        generateRequiredChunk(rc);
    }
}

fn generateRequiredChunk(rc: requiredChunkScript) void {
    game.state.db.saveChunkScript(rc.script_name, rc.chunk_script, rc.color) catch @panic("db error");
}

pub fn generateRequiredTerrainScripts() void {
    for (required_terrain_scripts) |rts| {
        generateRequiredTerrainScript(rts);
    }
}

fn generateRequiredTerrainScript(rts: requiredTerrainScript) void {
    game.state.db.saveTerrainGenScript(rts.script_name, rts.terrain_script, rts.color) catch @panic("db error");
}

const std = @import("std");
const script = @import("../script/script.zig");
const game = @import("../game.zig");
