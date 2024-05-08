pub fn evalTerrainFunc(allocator: std.mem.Allocator, luaInstance: *ziglua.Lua, buf: []const u8) !*desc.root {
    var b = script_descripter_builder.init(allocator, luaInstance);
    errdefer b.root.deinit();
    defer b.deinit();
    b.build_descriptor();

    const slices: [1][]const u8 = [_][]const u8{buf};
    const luaCString: [:0]const u8 = try std.mem.concatWithSentinel(
        allocator,
        u8,
        &slices,
        0,
    );
    defer allocator.free(luaCString);

    luaInstance.doString(luaCString) catch |err| {
        std.log.err("evalTerrainFunc: failed to eval lua code from string {s}.", .{luaCString});
        return err;
    };

    return b.root;
}

const std = @import("std");
const ziglua = @import("ziglua");
const script_utils = @import("script_utils.zig");
const script_descripter_builder = @import("script_descriptor_builder.zig");
const block = @import("../block/block.zig");
const chunk = block.chunk;
const desc = chunk.descriptor;
