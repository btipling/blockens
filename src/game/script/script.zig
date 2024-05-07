const Lua = ziglua.Lua;

pub const maxLuaScriptSize = script_utils.maxLuaScriptSize;
pub const maxLuaScriptNameSize = script_utils.maxLuaScriptNameSize;

pub const Script = struct {
    luaInstance: Lua,
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,
    pub fn init(allocator: std.mem.Allocator) !Script {
        var lua: Lua = try Lua.init(allocator);
        lua.openLibs();
        return Script{
            .luaInstance = lua,
            .allocator = allocator,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *Script) void {
        self.luaInstance.deinit();
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
};

const std = @import("std");
const ziglua = @import("ziglua");
const data = @import("../data/data.zig");
const state = @import("../state.zig");
const script_texture = @import("script_texture.zig");
const script_chunk = @import("script_chunk.zig");
const script_terrain = @import("script_terrain.zig");
const script_utils = @import("script_utils.zig");

pub const utils = script_utils;
