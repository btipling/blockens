pub fn utest_add_floor_at_y(data: []u32, y: f32, ll: block.BlockLighingLevel) void {
    {
        // set a lit ground floor across y = 63 on bottom chunk
        var ground_bd: block.BlockData = block.BlockData.fromId(1);
        ground_bd.setFullAmbiance(.none);
        ground_bd.setAmbient(.top, ll);
        const gd: u32 = ground_bd.toId();
        var x: f32 = 0;
        while (x < chunk.chunkDim) : (x += 1) {
            var z: f32 = 0;
            while (z < chunk.chunkDim) : (z += 1) {
                const ci = chunk.getIndexFromPositionV(.{ x, y, z, 0 });
                data[ci] = gd;
            }
        }
    }
}

pub fn utest_add_plane_at_y(
    data: []u32,
    pos: @Vector(4, f32),
    dimension: usize,
    surface: block.BlockSurface,
    ll: block.BlockLighingLevel,
) void {
    {
        std.debug.assert(@as(usize, @intFromFloat(pos[0])) + dimension < chunk.chunkDim);
        std.debug.assert(@as(usize, @intFromFloat(pos[2])) + dimension < chunk.chunkDim);
        // set a lit ground floor across y = 63 on bottom chunk
        var ground_bd: block.BlockData = block.BlockData.fromId(1);
        ground_bd.setFullAmbiance(.none);
        ground_bd.setAmbient(surface, ll);
        const gd: u32 = ground_bd.toId();
        var _x: usize = 0;
        while (_x < dimension) : (_x += 1) {
            const x: f32 = @floatFromInt(_x);
            var _z: usize = 0;
            while (_z < dimension) : (_z += 1) {
                const z: f32 = @floatFromInt(_z);
                const ci = chunk.getIndexFromPositionV(.{ pos[0] + x, pos[1], pos[2] + z, pos[3] });
                data[ci] = gd;
            }
        }
    }
}

pub fn utest_allocate_test_chunk(id: u32, ambiance: block.BlockLighingLevel) []u32 {
    const data = std.testing.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
    {
        var init_bd: block.BlockData = block.BlockData.fromId(id);
        init_bd.setFullAmbiance(ambiance);
        const init_data: u32 = init_bd.toId();
        var d: [chunk.chunkSize]u32 = undefined;
        @memset(&d, init_data);
        @memcpy(data, d[0..]);
    }
    return data;
}

pub fn utest_expect_surface_light_at_v(
    data: []u32,
    pos: @Vector(4, f32),
    surface: block.BlockSurface,
    expected_ll: block.BlockLighingLevel,
) !void {
    const b_ci = chunk.getIndexFromPositionV(pos);
    var below_bd: block.BlockData = block.BlockData.fromId(data[b_ci]);
    try std.testing.expectEqual(expected_ll, below_bd.getSurfaceAmbience(surface));
}

pub fn utest_chunk_ae_lighting(y: f32) ambient_edit.Lighting {
    const t_wp = chunk.worldPosition.initFromPositionV(.{ 0, y, 0, 0 });
    var l: ambient_edit.Lighting = .{
        .wp = t_wp,
        .pos = t_wp.vecFromWorldPosition(),
        .fetcher = .{},
        .allocator = std.testing.allocator_instance.allocator(),
    };
    l.fetcher.init();
    return l;
}

pub fn utest_set_block_surface_light(
    data: []u32,
    ci: usize,
    clear_ll: block.BlockLighingLevel,
    surface: block.BlockSurface,
    ll: block.BlockLighingLevel,
) void {
    var bd: block.BlockData = block.BlockData.fromId(1);
    bd.setFullAmbiance(clear_ll);
    bd.setAmbient(surface, ll);
    data[ci] = bd.toId();
}

const std = @import("std");
const ambient_edit = @import("lighting_ambient_edit.zig");
const block = @import("block.zig");
const chunk = block.chunk;
