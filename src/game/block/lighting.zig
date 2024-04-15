const air: u8 = 0;
const max_propagation_distance: u8 = 3;

const Lighting = @This();

pub const datas = struct {
    wp: chunk.worldPosition,
    data: ?[]u32 = null,
    fetchable: bool = true,
};

wp: chunk.worldPosition,
pos: @Vector(4, f32),
propagated: [chunk.chunkSize]u1 = std.mem.zeroes([chunk.chunkSize]u1),
allocator: std.mem.Allocator,
fetcher: data_fetcher,
datas: [7]datas = undefined,
num_extra_datas: u8 = 0,

pub fn deinit(self: Lighting) void {
    var i: usize = 1;
    while (i < self.num_extra_datas + 1) : (i += 1) {
        const d = self.datas[i];
        if (d.data) |cd| self.allocator.free(cd);
    }
}

pub fn get_datas(self: *Lighting, wp: chunk.worldPosition) ?[]u32 {
    var i: usize = 0;
    while (i < self.num_extra_datas + 1) : (i += 1) {
        const d = self.datas[i];
        if (d.wp.equal(wp)) {
            if (d.fetchable) return d.data;
            return null;
        }
    }
    const d = self.fetcher.fetch(wp) orelse {
        const ed: datas = .{
            .wp = wp,
            .fetchable = false,
        };
        self.datas[self.num_extra_datas] = ed;
        self.num_extra_datas += 1;
        return null;
    };

    self.datas[self.num_extra_datas + 1] = d;
    self.num_extra_datas += 1;
    return d.data;
}

pub fn set_removed_block_lighting(self: *Lighting, ci: usize) void {
    const pos = chunk.getPositionAtIndexV(ci);
    // Get light from above and see if it's full, have to propagate full all the way down
    y_pos: {
        var c_ci: usize = 0;
        var c_bd: block.BlockData = undefined;
        var _y: f32 = pos[1] + 1;
        if (_y >= chunk.chunkDim) {
            _y = chunk.chunkDim - 1;
            // Assume full light for now for missing chunk.
        } else {
            c_ci = chunk.getIndexFromPositionV(.{ pos[0], _y, pos[2], pos[3] });
            if (c_ci >= chunk.chunkSize) std.debug.panic("invalid y_pos >= chunk size", .{});
            const data = self.get_datas(self.wp) orelse return;
            c_bd = block.BlockData.fromId((data[c_ci]));
            // Only if the block above is air and full
            if (c_bd.block_id != air) break :y_pos;
            const c_ll = c_bd.getFullAmbiance();
            if (c_ll != .full) {
                break :y_pos;
            }
        }
        var multi_chunk = false;
        if (self.pos[1] == 1) {
            multi_chunk = true;
            _y += chunk.chunkDim;
        }
        while (_y >= 0) : (_y -= 1) {
            var wp = self.wp;
            const y = blk: {
                if (multi_chunk) {
                    if (_y < chunk.chunkDim) {
                        wp = wp.getBelowWP();
                        break :blk _y;
                    }
                    break :blk _y - chunk.chunkDim;
                }
                break :blk _y;
            };
            // let the light fall
            c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
            var data = self.get_datas(wp) orelse return;
            c_bd = block.BlockData.fromId(data[c_ci]);
            if (c_bd.block_id != air) {
                // reached the surface
                c_bd.setFullAmbiance(.full);
                c_bd.setAmbient(.top, .full);
                data[c_ci] = c_bd.toId();
                return;
            }
            // set air to full
            c_bd.setFullAmbiance(.full);
            data[c_ci] = c_bd.toId();
            // Set all the non-vertical adjacent surfaces to full or propagate light a bit
            x_pos: {
                const x = pos[0] + 1;
                if (x >= chunk.chunkDim) break :x_pos;
                c_ci = chunk.getIndexFromPositionV(.{ x, y, pos[2], pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.left, .full);
                    data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_ci);
            }
            x_neg: {
                const x = pos[0] - 1;
                if (x < 0) break :x_neg;
                c_ci = chunk.getIndexFromPositionV(.{ x, y, pos[2], pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.right, .full);
                    data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_ci);
            }
            z_pos: {
                const z = pos[2] + 1;
                if (z >= chunk.chunkDim) break :z_pos;
                c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, z, pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.front, .full);
                    data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_ci);
            }
            z_neg: {
                const z = pos[2] - 1;
                if (z < 0) break :z_neg;
                c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, z, pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.back, .full);
                    data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_ci);
            }
        }
        return;
    }
    self.set_propagated_lighting(ci);
}

pub fn set_added_block_lighting(self: *Lighting, bd: *block.BlockData, ci: usize) void {
    const pos = chunk.getPositionAtIndexV(ci);
    // set added block surfaces first
    self.set_surfaces_from_ambient(bd, ci);

    // If the block above was full lighting all light below has to be dimmed and propagated
    y_pos: {
        var c_ci: usize = 0;
        var c_bd: block.BlockData = undefined;
        var y = pos[1] - 1;
        if (y < 0) {
            // TODO: propagate to chunk below
            break :y_pos;
        }
        c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
        const c_ll: block.BlockLighingLevel = self.get_ambience_from_adjecent(c_ci, ci);
        while (y >= 0) : (y -= 1) {
            // let the darkness fall
            c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
            const data = self.get_datas(self.wp) orelse return;
            c_bd = block.BlockData.fromId(data[c_ci]);
            if (c_bd.block_id != air) {
                // reached the surface
                c_bd.setAmbient(.top, c_ll);
                data[c_ci] = c_bd.toId();
                return;
            }
            // set air to darkened light
            c_bd.setFullAmbiance(c_ll);
            data[c_ci] = c_bd.toId();
            // Set all the non-vertical adjacent surfaces to c_ll or propagate light a bit
            x_pos: {
                const x = pos[0] + 1;
                if (x >= chunk.chunkDim) break :x_pos;
                c_ci = chunk.getIndexFromPositionV(.{ x, y, pos[2], pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.left, c_ll);
                    data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_ci);
            }
            x_neg: {
                const x = pos[0] - 1;
                if (x < 0) break :x_neg;
                c_ci = chunk.getIndexFromPositionV(.{ x, y, pos[2], pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.right, c_ll);
                    data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_ci);
            }
            z_pos: {
                const z = pos[2] + 1;
                if (z >= chunk.chunkDim) break :z_pos;
                c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, z, pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.front, c_ll);
                    data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_ci);
            }
            z_neg: {
                const z = pos[2] - 1;
                if (z < 0) break :z_neg;
                c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, z, pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.back, c_ll);
                    data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_ci);
            }
        }
    }
}

pub fn set_surfaces_from_ambient(self: *Lighting, bd: *block.BlockData, ci: usize) void {
    bd.setFullAmbiance(.none);
    const pos = chunk.getPositionAtIndexV(ci);
    x_pos: {
        const x = pos[0] + 1;
        if (x >= chunk.chunkDim) break :x_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
        if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
        self.lightCheckDimensional(c_ci, bd, .right);
    }
    x_neg: {
        const x = pos[0] - 1;
        if (x < 0) break :x_neg;
        const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
        self.lightCheckDimensional(c_ci, bd, .left);
    }
    y_pos: {
        const y = pos[1] + 1;
        if (y >= chunk.chunkDim) break :y_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
        self.lightCheckDimensional(c_ci, bd, .top);
    }
    y_neg: {
        const y = pos[1] - 1;
        if (y < 0) break :y_neg;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
        self.lightCheckDimensional(c_ci, bd, .bottom);
    }
    z_pos: {
        const z = pos[2] + 1;
        if (z >= chunk.chunkDim) break :z_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
        if (c_ci >= chunk.chunkSize) std.debug.panic("invalid z_pos >= chunk size", .{});
        self.lightCheckDimensional(c_ci, bd, .back);
    }
    z_neg: {
        const z = pos[2] - 1;
        if (z < 0) break :z_neg;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
        self.lightCheckDimensional(c_ci, bd, .front);
    }

    var data = self.get_datas(self.wp) orelse return;
    data[ci] = bd.toId();
}

// This just fixes the lighting for each block as it should be without any context as
// to what else has changed. It doesn't rain down light or shadow. If nothing changed
// it stops. If something changed and its air it propagates more until things stop changing.
pub fn set_propagated_lighting(self: *Lighting, ci: usize) void {
    self.set_propagated_lighting_with_distance(ci, 0);
}

pub fn set_propagated_lighting_with_distance(self: *Lighting, ci: usize, distance: u8) void {
    if (distance >= max_propagation_distance) return;
    if (self.propagated[ci] == 1) return;
    self.propagated[ci] = 1;
    const pos = chunk.getPositionAtIndexV(ci);
    var data = self.get_datas(self.wp) orelse return;
    var bd: block.BlockData = block.BlockData.fromId(data[ci]);

    if (bd.block_id == air) {
        var ll = self.get_ambience_from_adjecent(ci, null);
        const ty = pos[1] + 1;
        if (ty < chunk.chunkDim) {
            // if block above is air just set this block to that
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], ty, pos[2], pos[3] });
            if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
            const c_bd: block.BlockData = block.BlockData.fromId(data[c_ci]);
            if (c_bd.block_id == air) ll = c_bd.getFullAmbiance();
        } else {
            ll = .full;
        }
        // if air set full ambience and if changed propagate changes to adjacent and down
        bd.setFullAmbiance(ll);
        data[ci] = bd.toId();
        x_neg: {
            const x = pos[0] - 1;
            if (x < 0) break :x_neg;
            const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
            self.set_propagated_lighting_with_distance(c_ci, distance + 1);
        }
        x_pos: {
            const x = pos[0] + 1;
            if (x >= chunk.chunkDim) break :x_pos;
            const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
            if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
            self.set_propagated_lighting_with_distance(c_ci, distance + 1);
        }
        y_neg: {
            const y = pos[1] - 1;
            if (y < 0) break :y_neg;
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
            self.set_propagated_lighting_with_distance(c_ci, distance);
        }
        z_neg: {
            const z = pos[2] - 1;
            if (z < 0) break :z_neg;
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
            self.set_propagated_lighting_with_distance(c_ci, distance + 1);
        }
        z_pos: {
            const z = pos[2] + 1;
            if (z >= chunk.chunkDim) break :z_pos;
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
            if (c_ci >= chunk.chunkSize) std.debug.panic("invalid z_pos >= chunk size", .{});
            self.set_propagated_lighting_with_distance(c_ci, distance + 1);
        }
        return;
    }
    // non-air just set surfaces of this block
    self.set_surfaces_from_ambient(&bd, ci);
}

pub fn getAirAmbiance(self: *Lighting, ci: usize) block.BlockLighingLevel {
    const data = self.get_datas(self.wp) orelse return .full;
    const c_bd: block.BlockData = block.BlockData.fromId((data[ci]));
    if (c_bd.block_id != air) return .none;
    return c_bd.getFullAmbiance().getNextDarker();
}

pub fn lightCheckDimensional(self: *Lighting, ci: usize, bd: *block.BlockData, s: block.BlockSurface) void {
    const data = self.get_datas(self.wp) orelse return;
    const c_bd: block.BlockData = block.BlockData.fromId((data[ci]));
    if (c_bd.block_id != air) bd.setAmbient(s, .none);
    const c_ll = c_bd.getFullAmbiance();
    bd.setAmbient(s, c_ll);
}

// source_ci - when we want brightness from any block other than the one queried from
pub fn get_ambience_from_adjecent(self: *Lighting, ci: usize, source_ci: ?usize) block.BlockLighingLevel {
    const pos = chunk.getPositionAtIndexV(ci);
    // now update adjacent
    var ll: block.BlockLighingLevel = .none;
    x_pos: {
        const x = pos[0] + 1;
        if (x >= chunk.chunkDim) break :x_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
        if (source_ci) |s_ci| if (c_ci == s_ci) break :x_pos;
        if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
        const c_ll = self.getAirAmbiance(c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    x_neg: {
        const x = pos[0] - 1;
        if (x < 0) break :x_neg;
        const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
        if (source_ci) |s_ci| if (c_ci == s_ci) break :x_neg;
        const c_ll = self.getAirAmbiance(c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    y_pos: {
        const y = pos[1] + 1;
        if (y >= chunk.chunkDim) break :y_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
        if (c_ci >= chunk.chunkSize) std.debug.panic("invalid y_pos >= chunk size", .{});
        if (source_ci) |s_ci| if (c_ci == s_ci) break :y_pos;
        const c_ll = self.getAirAmbiance(c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    z_pos: {
        const z = pos[2] + 1;
        if (z >= chunk.chunkDim) break :z_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
        if (c_ci >= chunk.chunkSize) std.debug.panic("invalid z_pos >= chunk size", .{});
        if (source_ci) |s_ci| if (c_ci == s_ci) break :z_pos;
        const c_ll = self.getAirAmbiance(c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    z_neg: {
        const z = pos[2] - 1;
        if (z < 0) break :z_neg;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
        if (source_ci) |s_ci| if (c_ci == s_ci) break :z_neg;
        const c_ll = self.getAirAmbiance(c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    return ll;
}

test "lighting init test" {
    const wp = chunk.worldPosition.initFromPositionV(.{ 0, 1, 0, 0 });
    var l: Lighting = .{
        .wp = wp,
        .pos = wp.vecFromWorldPosition(),
        .fetcher = .{},
        .allocator = std.testing.allocator_instance.allocator(),
    };
    defer l.deinit();
    const chunk_index: usize = 0;
    const block_id: u8 = 1;
    const data = l.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
    defer l.allocator.free(data);
    {
        var d: [chunk.chunkSize]u32 = std.mem.zeroes([chunk.chunkSize]u32);
        d[chunk_index] = block_id;
        @memcpy(data, d[0..]);
    }
    l.datas[0] = .{
        .wp = wp,
        .data = data,
    };
    var bd: block.BlockData = block.BlockData.fromId(data[chunk_index]);
    l.set_added_block_lighting(&bd, chunk_index);
    try std.testing.expectEqual(bd.block_id, block_id);
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
const data_fetcher = blk: {
    const builtin = @import("builtin");
    if (builtin.is_test) {
        break :blk @import("test_data_fetcher.zig");
    }
    break :blk @import("data_fetcher.zig");
};
