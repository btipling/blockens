pub fn evalTextureFunc(allocator: std.mem.Allocator, luaInstance: *ziglua.Lua, buf: [script_utils.maxLuaScriptSize]u8) !?[]u32 {
    luaInstance.setTop(0);
    var textureRGBAColor: [data.RGBAColorTextureSize]u32 = [_]u32{0} ** data.RGBAColorTextureSize;
    var luaCode: [script_utils.maxLuaScriptSize]u8 = [_]u8{0} ** script_utils.maxLuaScriptSize;
    var nullIndex: usize = 0;
    for (buf) |c| {
        if (c == 0) {
            break;
        }
        luaCode[nullIndex] = c;
        nullIndex += 1;
    }
    const luaCString: [:0]const u8 = luaCode[0..nullIndex :0];
    luaInstance.doString(luaCString) catch |err| {
        std.log.err("evalTextureFunc: failed to eval lua code from string {}.", .{err});
        return null;
    };
    _ = luaInstance.getGlobal("textures") catch |err| {
        std.log.err("evalTextureFunc: failed to get global textures. {}", .{err});
        return err;
    };
    if (luaInstance.isTable(-1) == false) {
        std.log.err("evalTextureFunc: textures is not a table", .{});
        return script_utils.ScriptError.ExpectedTable;
    }
    luaInstance.len(-1);
    const tableSize = luaInstance.toInteger(-1) catch |err| {
        std.log.err("evalTextureFunc: failed to get table size", .{});
        return err;
    };
    const ts = @as(usize, @intCast(tableSize));
    std.debug.print("evalTextureFunc: table size: {d}\n", .{ts});
    luaInstance.pop(1);
    if (luaInstance.isTable(-1) == false) {
        std.log.err("evalTextureFunc: textures is not back to a table", .{});
        return script_utils.ScriptError.ExpectedTable;
    }
    for (1..(ts + 1)) |i| {
        _ = luaInstance.rawGetIndex(-1, @intCast(i));
        const color = luaInstance.toInteger(-1) catch |err| {
            std.log.err("evalTextureFunc: failed to get color", .{});
            return err;
        };
        textureRGBAColor[i - 1] = @as(u32, @intCast(color));
        luaInstance.pop(1);
    }
    const rv: []u32 = try allocator.alloc(u32, textureRGBAColor.len);
    @memcpy(rv, &textureRGBAColor);
    return rv;
}

const std = @import("std");
const ziglua = @import("ziglua");
const data = @import("../data/data.zig");
const script_utils = @import("script_utils.zig");
