const air: u8 = 0;
const max_trigger_depth: u8 = 3;

pub fn light_fall(t_data: []u32, b_data: []u32) void {
    // Clear out all the ambient.
    for (0..chunk.chunkSize) |i| {
        var bd: block.BlockData = block.BlockData.fromId(t_data[i]);
        bd.clearAmbient();
        t_data[i] = bd.toId();
        bd = block.BlockData.fromId(b_data[i]);
        bd.clearAmbient();
        b_data[i] = bd.toId();
    }
    var z: isize = 0;
    while (z < 64) : (z += 1) {
        var x: isize = 0;
        while (x < 64) : (x += 1) {
            var y: isize = 127;
            while (true) : (y -= 1) {
                // flow in 5 directions and mark any block for that surface as lit
                if (y >= 64) {
                    const _y = @mod(y, 64);
                    if (!runY(t_data, x, _y, z)) break;
                } else {
                    if (!runY(b_data, x, y, z)) break;
                    if (y == 0) {
                        break;
                    }
                }
            }
        }
    }
    var y: i8 = 1;
    while (y >= 0) : (y -= 1) {
        var level: block.BlockLighingLevel = .full;
        while (level != .none) {
            var i: usize = 0;
            while (i < chunk.chunkSize) : (i += 1) {
                if (y == 1) {
                    setAirBasedOnSurroundings(t_data, i);
                } else {
                    setAirBasedOnSurroundings(b_data, i);
                }
            }
            level = switch (level) {
                .full => .bright,
                .bright => .dark,
                .dark => .none,
                .none => .none,
            };
        }
    }
    transferAmbianceToBelow(t_data, b_data);
}

fn transferAmbianceToBelow(t_data: []u32, b_data: []u32) void {
    for (0..chunk.chunkDim) |_x| {
        const x: f32 = @floatFromInt(_x);
        for (0..chunk.chunkDim) |_z| {
            const z: f32 = @floatFromInt(_z);
            const ti = chunk.getIndexFromPositionV(.{ x, 0, z, 1 });
            const t_bd: block.BlockData = block.BlockData.fromId(t_data[ti]);
            if (t_bd.block_id != air) continue;
            if (t_bd.getFullAmbiance() == .none) continue;
            const bi = chunk.getIndexFromPositionV(.{ x, 63, z, 1 });
            var b_bd: block.BlockData = block.BlockData.fromId(b_data[bi]);
            if (b_bd.block_id == air) continue;
            b_bd.setAmbient(.top, t_bd.getFullAmbiance());
            b_data[bi] = b_bd.toId();
        }
    }
}

fn setAirBasedOnSurroundings(c_data: []u32, i: usize) void {
    var bd: block.BlockData = block.BlockData.fromId(c_data[i]);
    if (bd.block_id != air) return;
    if (bd.getFullAmbiance() != .none) return;
    const block_index = chunk.getPositionAtIndexV(i);
    var brightest_l: block.BlockLighingLevel = .none;
    {
        const ll = isAmbientSource(c_data, .{ block_index[0], block_index[1], block_index[2] + 1, block_index[3] });
        if (ll.isBrighterThan(brightest_l)) brightest_l = ll;
    }
    {
        const ll = isAmbientSource(c_data, .{ block_index[0], block_index[1], block_index[2] - 1, block_index[3] });
        if (ll.isBrighterThan(brightest_l)) brightest_l = ll;
    }
    {
        const ll = isAmbientSource(c_data, .{ block_index[0] + 1, block_index[1], block_index[2], block_index[3] });
        if (ll.isBrighterThan(brightest_l)) brightest_l = ll;
    }
    {
        const ll = isAmbientSource(c_data, .{ block_index[0] - 1, block_index[1], block_index[2], block_index[3] });
        if (ll.isBrighterThan(brightest_l)) brightest_l = ll;
    }
    const ll = brightest_l.getNextDarker();
    if (ll != .none) {
        bd.setFullAmbiance(ll);
        c_data[i] = bd.toId();
        setSurroundingAmbience(c_data, i, ll);
    }
    return;
}

fn setSurroundingAmbience(c_data: []u32, i: usize, level: block.BlockLighingLevel) void {
    const block_index = chunk.getPositionAtIndexV(i);
    setAmbient(
        c_data,
        .{ block_index[0], block_index[1], block_index[2] + 1, block_index[3] },
        level,
        .front,
    );
    setAmbient(
        c_data,
        .{ block_index[0], block_index[1], block_index[2] - 1, block_index[3] },
        level,
        .back,
    );
    setAmbient(
        c_data,
        .{ block_index[0] + 1, block_index[1], block_index[2], block_index[3] },
        level,
        .left,
    );
    setAmbient(
        c_data,
        .{ block_index[0] - 1, block_index[1], block_index[2], block_index[3] },
        level,
        .right,
    );
    setAmbient(
        c_data,
        .{ block_index[0], block_index[1] - 1, block_index[2], block_index[3] },
        level,
        .top,
    );
    setAmbient(
        c_data,
        .{ block_index[0], block_index[1] + 1, block_index[2], block_index[3] },
        level,
        .bottom,
    );
}

fn isAmbientSource(c_data: []u32, pos: @Vector(4, f32)) block.BlockLighingLevel {
    const f_dim: f32 = @floatFromInt(chunk.chunkDim);
    if (pos[0] < 0) return .none;
    if (pos[1] < 0) return .none;
    if (pos[2] < 0) return .none;
    if (pos[0] >= f_dim) return .none;
    if (pos[1] >= f_dim) return .none;
    if (pos[2] >= f_dim) return .none;
    const i = chunk.getIndexFromPositionV(pos);
    const bd = block.BlockData.fromId(c_data[i]);
    if (bd.block_id != air) return .none; // TODO: support transparent blocks.
    return bd.getFullAmbiance();
}

fn setAmbient(
    c_data: []u32,
    pos: @Vector(4, f32),
    level: block.BlockLighingLevel,
    surface: block.BlockSurface,
) void {
    if (pos[0] < 0) return;
    if (pos[1] < 0) return;
    if (pos[2] < 0) return;
    const i = chunk.getIndexFromPositionV(pos);
    var bd = block.BlockData.fromId(c_data[i]);
    if (bd.block_id == air) return;
    bd.setAmbient(surface, level);
    c_data[i] = bd.toId();
}

fn runY(c_data: []u32, x: isize, y: isize, z: isize) bool {
    const chunk_index: usize = @intCast(x + y * 64 + z * 64 * 64);
    // check below, if hit, stop checking for this y.
    var bd: block.BlockData = block.BlockData.fromId(c_data[chunk_index]);
    if (bd.block_id == air) {
        bd.setFullAmbiance(.full);
        c_data[chunk_index] = bd.toId();
        setSurroundingAmbience(c_data, chunk_index, .full);
    } else {
        bd.setAmbient(.top, .full);
        c_data[chunk_index] = bd.toId();
        return false;
    }
    return true;
}

test "floating plane lighting test" {
    // The bottom surface of a floating plane should have shade increasing in darkness closer to its center.
    const t_data = testing_utils.utest_allocate_test_chunk(0, .full);
    defer std.testing.allocator.free(t_data);

    const b_data = testing_utils.utest_allocate_test_chunk(0, .full);
    defer std.testing.allocator.free(b_data);

    const plane_pos: @Vector(4, f32) = .{ 10, 5, 10, 0 };
    const plane_dim: usize = 5;
    testing_utils.utest_add_plane_at_y(b_data, plane_pos, plane_dim, .bottom, .full);

    testing_utils.utest_add_floor_at_y(b_data, 0, .full);

    light_fall(t_data, b_data);

    {
        // test top surface of plane is fully lit:
        var _x: usize = 0;
        while (_x < plane_dim) : (_x += 1) {
            var _z: usize = 0;
            while (_z < plane_dim) : (_z += 1) {
                const x: f32 = @floatFromInt(_x);
                const z: f32 = @floatFromInt(_z);
                try testing_utils.utest_expect_surface_light_at_v(
                    b_data,
                    .{
                        plane_pos[0] + x,
                        plane_pos[1],
                        plane_pos[2] + z,
                        plane_pos[3],
                    },
                    .top,
                    .full,
                );
            }
        }
    }

    try std.testing.expect(true);
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
const testing_utils = @import("testing_utils.zig");
