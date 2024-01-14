const std = @import("std");
const ziglua = @import("ziglua");
const gl = @import("zopengl");
const data = @import("../data/data.zig");
const state = @import("../state.zig");

const Lua = ziglua.Lua;

const ScriptError = error{
    ExpectedTable,
};

pub const maxLuaScriptSize = 360_000;
pub const maxLuaScriptNameSize = 20;

pub const Script = struct {
    luaInstance: Lua,
    pub fn init(alloc: std.mem.Allocator) !Script {
        var lua: Lua = try Lua.init(alloc);
        lua.openLibs();
        return Script{
            .luaInstance = lua,
        };
    }

    pub fn deinit(self: *Script) void {
        self.luaInstance.deinit();
    }

    pub fn evalTextureFunc(self: *Script, buf: [maxLuaScriptSize]u8) ![data.RGBAColorTextureSize]gl.Uint {
        std.debug.print("evalTextureFunc from lua {d}\n", .{buf.len});
        var luaCode: [maxLuaScriptSize]u8 = [_]u8{0} ** maxLuaScriptSize;
        var nullIndex: usize = 0;
        for (buf) |c| {
            if (c == 0) {
                break;
            }
            luaCode[nullIndex] = c;
            nullIndex += 1;
        }
        const luaCString: [:0]const u8 = luaCode[0..nullIndex :0];
        std.debug.print("evalTextureFunc: nullIndex: {d} \n", .{nullIndex});
        self.luaInstance.doString(luaCString) catch |err| {
            std.log.err("evalTextureFunc: failed to eval lua code from string {s}.", .{luaCString});
            return err;
        };
        _ = self.luaInstance.getGlobal("textures") catch |err| {
            std.log.err("evalTextureFunc: failed to get global textures. {}", .{err});
            return err;
        };
        if (self.luaInstance.isTable(-1) == false) {
            std.log.err("evalTextureFunc: textures is not a table", .{});
            return ScriptError.ExpectedTable;
        }
        self.luaInstance.len(-1);
        const tableSize = self.luaInstance.toInteger(-1) catch |err| {
            std.log.err("evalTextureFunc: failed to get table size", .{});
            return err;
        };
        const ts = @as(usize, @intCast(tableSize));
        std.debug.print("evalTextureFunc: table size: {d}\n", .{ts});
        self.luaInstance.pop(1);
        if (self.luaInstance.isTable(-1) == false) {
            std.log.err("evalTextureFunc: textures is not back to a table", .{});
            return ScriptError.ExpectedTable;
        }
        var textureRGBAColor: [data.RGBAColorTextureSize]gl.Uint = [_]gl.Uint{0} ** data.RGBAColorTextureSize;
        for (1..(ts + 1)) |i| {
            _ = self.luaInstance.rawGetIndex(-1, @intCast(i));
            const color = self.luaInstance.toInteger(-1) catch |err| {
                std.log.err("evalTextureFunc: failed to get color", .{});
                return err;
            };
            textureRGBAColor[i - 1] = @as(gl.Uint, @intCast(color));
            self.luaInstance.pop(1);
        }
        return textureRGBAColor;
    }

    pub fn evalChunkFunc(self: *Script, buf: [maxLuaScriptSize]u8) ![state.chunkSize]gl.Uint {
        std.debug.print("evalChunkFunc from lua {d}\n", .{buf.len});
        var luaCode: [maxLuaScriptSize]u8 = [_]u8{0} ** maxLuaScriptSize;
        var nullIndex: usize = 0;
        for (buf) |c| {
            if (c == 0) {
                break;
            }
            luaCode[nullIndex] = c;
            nullIndex += 1;
        }
        const luaCString: [:0]const u8 = luaCode[0..nullIndex :0];
        std.debug.print("evalChunkFunc: nullIndex: {d} \n", .{nullIndex});
        self.luaInstance.doString(luaCString) catch |err| {
            std.log.err("evalChunkFunc: failed to eval lua code from string {s}.", .{luaCString});
            return err;
        };
        _ = self.luaInstance.getGlobal("chunk") catch |err| {
            std.log.err("evalChunkFunc: failed to get global chunks. {}", .{err});
            return err;
        };
        if (self.luaInstance.isTable(-1) == false) {
            std.log.err("evalChunkFunc: chunks is not a table", .{});
            return ScriptError.ExpectedTable;
        }
        self.luaInstance.len(-1);
        const tableSize = self.luaInstance.toInteger(-1) catch |err| {
            std.log.err("evalChunkFunc: failed to get table size", .{});
            return err;
        };
        const ts = @as(usize, @intCast(tableSize));
        std.debug.print("evalChunkFunc: table size: {d}\n", .{ts});
        self.luaInstance.pop(1);
        if (self.luaInstance.isTable(-1) == false) {
            std.log.err("evalChunkFunc: chunks is not back to a table", .{});
            return ScriptError.ExpectedTable;
        }
        var chunk: [state.chunkSize]gl.Uint = [_]gl.Uint{0} ** state.chunkSize;
        for (1..(ts + 1)) |i| {
            _ = self.luaInstance.rawGetIndex(-1, @intCast(i));
            const blockId = self.luaInstance.toInteger(-1) catch |err| {
                std.log.err("evalChunkFunc: failed to get color", .{});
                return err;
            };
            chunk[i - 1] = @as(gl.Uint, @intCast(blockId));
            self.luaInstance.pop(1);
        }
        std.debug.print("\n", .{});
        return chunk;
    }
};
