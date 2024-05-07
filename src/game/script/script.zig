const Lua = ziglua.Lua;

pub const maxLuaScriptSize = script_utils.maxLuaScriptSize;
pub const maxLuaScriptNameSize = script_utils.maxLuaScriptNameSize;

var noiseGen: *znoise.FnlGenerator = undefined;

fn genNoise(lua: *Lua) i32 {
    const x: f32 = @floatCast(lua.toNumber(1) catch 0);
    const y: f32 = @floatCast(lua.toNumber(2) catch 0);
    const z: f32 = @floatCast(lua.toNumber(3) catch 0);
    const n = noiseGen.noise3(x, y, z);
    lua.pushNumber(@floatCast(n));
    return 1;
}

pub const Script = struct {
    luaInstance: Lua,
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,
    pub fn init(allocator: std.mem.Allocator) !Script {
        var lua: Lua = try Lua.init(allocator);
        lua.openLibs();
        noiseGen = allocator.create(znoise.FnlGenerator) catch @panic("OOM");

        noiseGen.* = znoise.FnlGenerator{
            .seed = 0,
            .frequency = -0.002,
            .noise_type = .opensimplex2,
            .rotation_type3 = .improve_xz_planes,
            .fractal_type = .fbm,
            .octaves = 10,
            .lacunarity = 1.350,
            .gain = 0.0,
            .weighted_strength = 0.0,
            .ping_pong_strength = 0.0,
            .cellular_distance_func = .euclidean,
            .cellular_return_type = .cellvalue,
            .cellular_jitter_mod = 2.31,
            .domain_warp_type = .basicgrid,
            .domain_warp_amp = 1.0,
        };

        return Script{
            .luaInstance = lua,
            .allocator = allocator,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *Script) void {
        self.luaInstance.deinit();
        self.allocator.destroy(noiseGen);
    }

    pub fn evalTextureFunc(self: *Script, buf: [maxLuaScriptSize]u8) !?[]u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return script_texture.evalTextureFunc(self.allocator, &self.luaInstance, buf);
    }

    pub fn evalChunkFunc(self: *Script, buf: []const u8) ![]u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return script_chunk.evalChunkFunc(self.allocator, &self.luaInstance, buf);
    }

    pub fn evalTerrainFunc(self: *Script, seed: i32, pos: @Vector(4, f32), buf: []const u8) ![]u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        std.debug.print("eval terrain starting\n", .{});
        noiseGen.seed = seed;
        self.luaInstance.setTop(0);
        {
            // push noise generator to lua
            self.luaInstance.pushFunction(ziglua.wrap(genNoise));
            self.luaInstance.setGlobal("gen_noise");
        }
        {
            // push chunk coordinates to lua
            self.luaInstance.pushNumber(@floatCast(pos[0]));
            self.luaInstance.setGlobal("chunk_x");
            self.luaInstance.pushNumber(@floatCast(pos[1]));
            self.luaInstance.setGlobal("chunk_y");
            self.luaInstance.pushNumber(@floatCast(pos[2]));
            self.luaInstance.setGlobal("chunk_z");
        }
        return script_terrain.evalTerrainFunc(self.allocator, &self.luaInstance, buf);
    }
};

const std = @import("std");
const ziglua = @import("ziglua");
const znoise = @import("znoise");
const data = @import("../data/data.zig");
const state = @import("../state.zig");
const script_texture = @import("script_texture.zig");
const script_chunk = @import("script_chunk.zig");
const script_terrain = @import("script_terrain.zig");
const script_utils = @import("script_utils.zig");

pub const utils = script_utils;
