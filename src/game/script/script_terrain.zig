pub fn evalTerrainFunc(
    allocator: std.mem.Allocator,
    luaInstance: *ziglua.Lua,
    pos: @Vector(4, f32),
    buf: []const u8,
) ![]u32 {
    _ = luaInstance; // autofix
    _ = buf; // autofix
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

        const rv: []u32 = try allocator.alloc(u32, chunk.chunkSize);
        @memset(rv, 0);
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
