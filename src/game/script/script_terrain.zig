pub fn evalTerrainFunc(
    allocator: std.mem.Allocator,
    luaInstance: *ziglua.Lua,
    pos: @Vector(4, f32),
    buf: []const u8,
) ![]u32 {
    {
        const gen = znoise.FnlGenerator{};
        const n2 = gen.noise2(0.1, 0.2);
        const n3 = gen.noise3(1.0, 2.0, 3.0);
        std.debug.print("noise2, what is this {}\n", .{n2});
        std.debug.print("noise3, what is this {}\n", .{n3});

        var x: f32 = pos[0];
        var y: f32 = pos[1];
        var z: f32 = pos[2];
        gen.domainWarp3(&x, &y, &z);
        std.debug.print("domainWarp3, what is this {} {} {}\n", .{ x, y, z });
    }

    {
        const gen = znoise.FnlGenerator{
            .seed = 1337,
            .frequency = 0.01,
            .noise_type = .opensimplex2,
            .rotation_type3 = .none,
            .fractal_type = .none,
            .octaves = 3,
            .lacunarity = 2.0,
            .gain = 0.5,
            .weighted_strength = 0.0,
            .ping_pong_strength = 2.0,
            .cellular_distance_func = .euclideansq,
            .cellular_return_type = .distance,
            .cellular_jitter_mod = 1.0,
            .domain_warp_type = .opensimplex2,
            .domain_warp_amp = 1.0,
        };
        const n = gen.noise2(0.1, 0.2);

        std.debug.print("FnlGenerator, what is this {}\n", .{n});
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
}

const std = @import("std");
const ziglua = @import("ziglua");
const znoise = @import("znoise");
const data = @import("../data/data.zig");
const script_utils = @import("script_utils.zig");
const block = @import("../block/block.zig");
const chunk = block.chunk;
