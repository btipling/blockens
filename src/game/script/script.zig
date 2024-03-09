const std = @import("std");
const ziglua = @import("ziglua");
const data = @import("../data/data.zig");
const state = @import("../state/state.zig");
const chunk = @import("../chunk.zig");

const Lua = ziglua.Lua;

const ScriptError = error{
    ExpectedTable,
};

pub const maxLuaScriptSize = 360_000;
pub const maxLuaScriptNameSize = 20;

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

        std.debug.print("evalTextureFunc from lua {d}\n", .{buf.len});
        self.luaInstance.setTop(0);
        var textureRGBAColor: [data.RGBAColorTextureSize]u32 = [_]u32{0} ** data.RGBAColorTextureSize;
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
            std.log.err("evalTextureFunc: failed to eval lua code from string {}.", .{err});
            return null;
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
        for (1..(ts + 1)) |i| {
            _ = self.luaInstance.rawGetIndex(-1, @intCast(i));
            const color = self.luaInstance.toInteger(-1) catch |err| {
                std.log.err("evalTextureFunc: failed to get color", .{});
                return err;
            };
            textureRGBAColor[i - 1] = @as(u32, @intCast(color));
            self.luaInstance.pop(1);
        }
        const rv: []u32 = try self.allocator.alloc(u32, textureRGBAColor.len);
        @memcpy(rv, &textureRGBAColor);
        return rv;
    }

    pub fn evalChunkFunc(self: *Script, buf: []u8) ![]i32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        std.debug.print("evalChunkFunc from lua {d}\n", .{buf.len});
        self.luaInstance.setTop(0);
        const slices: [1][]u8 = [_][]u8{buf};
        const luaCString: [:0]u8 = try std.mem.concatWithSentinel(
            self.allocator,
            u8,
            &slices,
            0,
        );
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
            std.log.err("evalChunkFunc: chunks is not back to a table\n", .{});
            return ScriptError.ExpectedTable;
        }
        var c: [chunk.chunkSize]i32 = [_]i32{0} ** chunk.chunkSize;
        for (1..(ts + 1)) |i| {
            _ = self.luaInstance.rawGetIndex(-1, @intCast(i));
            const blockId = self.luaInstance.toInteger(-1) catch |err| {
                std.log.err("evalChunkFunc: failed to get color\n", .{});
                return err;
            };
            c[i - 1] = @as(i32, @intCast(blockId));
            self.luaInstance.pop(1);
        }
        const rv: []i32 = try self.allocator.alloc(i32, c.len);
        @memcpy(rv, &c);
        return rv;
    }

    pub fn dataScriptToScript(scriptData: [360_001]u8) [maxLuaScriptSize]u8 {
        var buf = [_]u8{0} ** maxLuaScriptSize;
        for (scriptData, 0..) |c, i| {
            if (i >= maxLuaScriptSize) {
                break;
            }
            buf[i] = c;
        }
        return buf;
    }
};
