pub fn evalChunkFunc(allocator: std.mem.Allocator, luaInstance: *ziglua.Lua, buf: []const u8) ![]u32 {
    luaInstance.setTop(0);
    const slices: [1][]const u8 = [_][]const u8{buf};
    const luaCString: [:0]const u8 = try std.mem.concatWithSentinel(
        allocator,
        u8,
        &slices,
        0,
    );
    defer allocator.free(luaCString);
    luaInstance.doString(luaCString) catch |err| {
        std.log.err("evalChunkFunc: failed to eval lua code from string {s}.", .{luaCString});
        return err;
    };
    _ = luaInstance.getGlobal("chunk") catch |err| {
        std.log.err("evalChunkFunc: failed to get global chunks. {}", .{err});
        return err;
    };
    if (luaInstance.isTable(-1) == false) {
        std.log.err("evalChunkFunc: chunks is not a table", .{});
        return script_utils.ScriptError.ExpectedTable;
    }
    luaInstance.len(-1);
    const tableSize = luaInstance.toInteger(-1) catch |err| {
        std.log.err("evalChunkFunc: failed to get table size", .{});
        return err;
    };
    const ts = @as(usize, @intCast(tableSize));
    luaInstance.pop(1);
    if (luaInstance.isTable(-1) == false) {
        std.log.err("evalChunkFunc: chunks is not back to a table\n", .{});
        return script_utils.ScriptError.ExpectedTable;
    }
    var c: [chunk.chunkSize]u32 = std.mem.zeroes([chunk.chunkSize]u32);
    for (1..(ts + 1)) |i| {
        _ = luaInstance.rawGetIndex(-1, @intCast(i));
        const blockId = luaInstance.toInteger(-1) catch |err| {
            std.log.err("evalChunkFunc: failed to get block\n", .{});
            return err;
        };
        c[i - 1] = @as(u32, @intCast(blockId));
        luaInstance.pop(1);
    }
    const rv: []u32 = try allocator.alloc(u32, c.len);
    @memcpy(rv, &c);
    return rv;
}

const std = @import("std");
const ziglua = @import("ziglua");
const data = @import("../data/data.zig");
const script_utils = @import("script_utils.zig");
const block = @import("../block/block.zig");
const chunk = block.chunk;
