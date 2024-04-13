const air: u8 = 0;
const max_propagation_distance: u8 = 3;

const Lighting = @This();

propagated: [chunk.chunkSize]u1 = std.mem.zeroes([chunk.chunkSize]u1),

pub fn set_removed_block_lighting(self: Lighting, c_data: []u32, ci: usize) void {
    const pos = chunk.getPositionAtIndexV(ci);
    // Get light from above and see if it's full, have to propagate full all the way down
    y_pos: {
        var c_ci: usize = 0;
        var c_bd: block.BlockData = undefined;
        var y = pos[1] + 1;
        if (y >= chunk.chunkDim) {
            y = chunk.chunkDim - 1;
            // Assume full light for now for missing chunk.
        } else {
            c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
            if (c_ci >= chunk.chunkSize) std.debug.panic("invalid y_pos >= chunk size", .{});
            c_bd = block.BlockData.fromId((c_data[c_ci]));
            // Only if the block above is air and full
            if (c_bd.block_id != air) break :y_pos;
            const c_ll = c_bd.getFullAmbiance();
            if (c_ll != .full) {
                break :y_pos;
            }
        }
        while (y >= 0) : (y -= 1) {
            // let the light fall
            c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
            c_bd = block.BlockData.fromId(c_data[c_ci]);
            if (c_bd.block_id != air) {
                // reached the surface
                c_bd.setAmbient(.top, .full);
                c_data[c_ci] = c_bd.toId();
                return;
            }
            // set air to full
            c_bd.setFullAmbiance(.full);
            c_data[c_ci] = c_bd.toId();
            // Set all the non-vertical adjacent surfaces to full or propagate light a bit
            x_pos: {
                const x = pos[0] + 1;
                if (x >= chunk.chunkDim) break :x_pos;
                c_ci = chunk.getIndexFromPositionV(.{ x, y, pos[2], pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.left, .full);
                    c_data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_data, c_ci);
            }
            x_neg: {
                const x = pos[0] - 1;
                if (x >= chunk.chunkDim) break :x_neg;
                c_ci = chunk.getIndexFromPositionV(.{ x, y, pos[2], pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.right, .full);
                    c_data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_data, c_ci);
            }
            z_pos: {
                const z = pos[2] + 1;
                if (z >= chunk.chunkDim) break :z_pos;
                c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, z, pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.front, .full);
                    c_data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_data, c_ci);
            }
            z_neg: {
                const z = pos[2] - 1;
                if (z >= chunk.chunkDim) break :z_neg;
                c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, z, pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.back, .full);
                    c_data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_data, c_ci);
            }
        }
        std.debug.print("unreachable.\n", .{});
        return;
    }
    self.set_propagated_lighting(c_data, ci);
}

pub fn set_added_block_lighting(self: Lighting, c_data: []u32, bd: *block.BlockData, ci: usize) void {
    const pos = chunk.getPositionAtIndexV(ci);
    // set added block surfaces first
    self.set_surfaces_from_ambient(c_data, bd, ci);

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
        const c_ll: block.BlockLighingLevel = get_ambience_from_adjecent(c_data, c_ci, ci);
        while (y >= 0) : (y -= 1) {
            // let the darkness fall
            c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
            c_bd = block.BlockData.fromId(c_data[c_ci]);
            if (c_bd.block_id != air) {
                // reached the surface
                c_bd.setAmbient(.top, c_ll);
                c_data[c_ci] = c_bd.toId();
                return;
            }
            // set air to darkened light
            c_bd.setFullAmbiance(c_ll);
            c_data[c_ci] = c_bd.toId();
            // Set all the non-vertical adjacent surfaces to c_ll or propagate light a bit
            x_pos: {
                const x = pos[0] + 1;
                if (x >= chunk.chunkDim) break :x_pos;
                c_ci = chunk.getIndexFromPositionV(.{ x, y, pos[2], pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.left, c_ll);
                    c_data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_data, c_ci);
            }
            x_neg: {
                const x = pos[0] - 1;
                if (x >= chunk.chunkDim) break :x_neg;
                c_ci = chunk.getIndexFromPositionV(.{ x, y, pos[2], pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.right, c_ll);
                    c_data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_data, c_ci);
            }
            z_pos: {
                const z = pos[2] + 1;
                if (z >= chunk.chunkDim) break :z_pos;
                c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, z, pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.front, c_ll);
                    c_data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_data, c_ci);
            }
            z_neg: {
                const z = pos[2] - 1;
                if (z >= chunk.chunkDim) break :z_neg;
                c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, z, pos[3] });
                if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.back, c_ll);
                    c_data[c_ci] = c_bd.toId();
                } else self.set_propagated_lighting(c_data, c_ci);
            }
        }
        std.debug.panic("not reachable", .{});
    }
}

pub fn set_surfaces_from_ambient(_: Lighting, c_data: []u32, bd: *block.BlockData, ci: usize) void {
    bd.setFullAmbiance(.none);
    const pos = chunk.getPositionAtIndexV(ci);
    x_pos: {
        const x = pos[0] + 1;
        if (x >= chunk.chunkDim) break :x_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
        if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
        lightCheckDimensional(c_data, c_ci, bd, .right);
    }
    x_neg: {
        const x = pos[0] - 1;
        if (x < 0) break :x_neg;
        const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
        lightCheckDimensional(c_data, c_ci, bd, .left);
    }
    y_pos: {
        const y = pos[1] + 1;
        if (y >= chunk.chunkDim) break :y_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
        lightCheckDimensional(c_data, c_ci, bd, .top);
    }
    y_neg: {
        const y = pos[1] - 1;
        if (y < 0) break :y_neg;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
        lightCheckDimensional(c_data, c_ci, bd, .bottom);
    }
    z_pos: {
        const z = pos[2] + 1;
        if (z >= chunk.chunkDim) break :z_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
        if (c_ci >= chunk.chunkSize) std.debug.panic("invalid z_pos >= chunk size", .{});
        lightCheckDimensional(c_data, c_ci, bd, .back);
    }
    z_neg: {
        const z = pos[2] - 1;
        if (z < 0) break :z_neg;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
        lightCheckDimensional(c_data, c_ci, bd, .front);
    }
    c_data[ci] = bd.toId();
}

// This just fixes the lighting for each block as it should be without any context as
// to what else has changed. It doesn't rain down light or shadow. If nothing changed
// it stops. If something changed and its air it propagates more until things stop changing.
pub fn set_propagated_lighting(self: Lighting, c_data: []u32, ci: usize) void {
    self.set_propagated_lighting_neg(c_data, ci, 0);
    self.set_propagated_lighting_pos(c_data, ci, 0);

    const pos = chunk.getPositionAtIndexV(ci);
    const bd: block.BlockData = block.BlockData.fromId(c_data[ci]);
    if (bd.block_id != air) return;
    y_neg: {
        const y = pos[1] - 1;
        if (y < 0) break :y_neg;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
        self.set_propagated_lighting(c_data, c_ci);
    }
}

pub fn set_propagated_lighting_neg(self: Lighting, c_data: []u32, ci: usize, distance: u8) void {
    if (distance >= max_propagation_distance) return;
    const pos = chunk.getPositionAtIndexV(ci);
    var bd: block.BlockData = block.BlockData.fromId(c_data[ci]);

    if (bd.block_id == air) {
        var ll = get_ambience_from_adjecent(c_data, ci, null);
        const ty = pos[1] + 1;
        if (ty < chunk.chunkDim) {
            // if block above is air just set this block to that
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], ty, pos[2], pos[3] });
            if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
            const c_bd: block.BlockData = block.BlockData.fromId(c_data[c_ci]);
            if (c_bd.block_id == air) ll = c_bd.getFullAmbiance();
        } else {
            ll = .full;
        }
        // if air set full ambience and if changed propagate changes to adjacent and down
        bd.setFullAmbiance(ll);
        c_data[ci] = bd.toId();
        x_neg: {
            const x = pos[0] - 1;
            if (x < 0) break :x_neg;
            const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
            self.set_propagated_lighting_neg(c_data, c_ci, distance + 1);
        }
        z_neg: {
            const z = pos[2] - 1;
            if (z < 0) break :z_neg;
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
            self.set_propagated_lighting_neg(c_data, c_ci, distance + 1);
        }
        return;
    }
    // non-air just set surfaces of this block
    self.set_surfaces_from_ambient(c_data, &bd, ci);
}

pub fn set_propagated_lighting_pos(self: Lighting, c_data: []u32, ci: usize, distance: u8) void {
    if (distance >= max_propagation_distance) return;
    const pos = chunk.getPositionAtIndexV(ci);
    var bd: block.BlockData = block.BlockData.fromId(c_data[ci]);

    if (bd.block_id == air) {
        var ll = get_ambience_from_adjecent(c_data, ci, null);
        const ty = pos[1] + 1;
        if (ty < chunk.chunkDim) {
            // if block above is air just set this block to that
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], ty, pos[2], pos[3] });
            if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
            const c_bd: block.BlockData = block.BlockData.fromId(c_data[c_ci]);
            if (c_bd.block_id == air) ll = c_bd.getFullAmbiance();
        } else {
            ll = .full;
        }
        // if air set full ambience and if changed propagate changes to adjacent and down
        bd.setFullAmbiance(ll);
        c_data[ci] = bd.toId();
        x_pos: {
            const x = pos[0] + 1;
            if (x >= chunk.chunkDim) break :x_pos;
            const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
            if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
            self.set_propagated_lighting_pos(c_data, c_ci, distance + 1);
        }
        z_pos: {
            const z = pos[2] + 1;
            if (z >= chunk.chunkDim) break :z_pos;
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
            if (c_ci >= chunk.chunkSize) std.debug.panic("invalid z_pos >= chunk size", .{});
            self.set_propagated_lighting_pos(c_data, c_ci, distance + 1);
        }
        return;
    }
    // non-air just set surfaces of this block
    self.set_surfaces_from_ambient(c_data, &bd, ci);
}

pub fn getAirAmbiance(c_data: []u32, ci: usize) block.BlockLighingLevel {
    const c_bd: block.BlockData = block.BlockData.fromId((c_data[ci]));
    if (c_bd.block_id != air) return .none;
    return c_bd.getFullAmbiance().getNextDarker();
}

pub fn lightCheckDimensional(c_data: []u32, ci: usize, bd: *block.BlockData, s: block.BlockSurface) void {
    const c_bd: block.BlockData = block.BlockData.fromId((c_data[ci]));
    if (c_bd.block_id != air) bd.setAmbient(s, .none);
    const c_ll = c_bd.getFullAmbiance();
    bd.setAmbient(s, c_ll);
}

// source_ci - when we want brightness from any block other than the one queried from
pub fn get_ambience_from_adjecent(c_data: []u32, ci: usize, source_ci: ?usize) block.BlockLighingLevel {
    const pos = chunk.getPositionAtIndexV(ci);
    // now update adjacent
    var ll: block.BlockLighingLevel = .none;
    x_pos: {
        const x = pos[0] + 1;
        if (x >= chunk.chunkDim) break :x_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
        if (source_ci) |s_ci| if (c_ci == s_ci) break :x_pos;
        if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
        const c_ll = getAirAmbiance(c_data, c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    x_neg: {
        const x = pos[0] - 1;
        if (x < 0) break :x_neg;
        const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
        if (source_ci) |s_ci| if (c_ci == s_ci) break :x_neg;
        const c_ll = getAirAmbiance(c_data, c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    y_pos: {
        const y = pos[1] + 1;
        if (y >= chunk.chunkDim) break :y_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
        if (c_ci >= chunk.chunkSize) std.debug.panic("invalid y_pos >= chunk size", .{});
        if (source_ci) |s_ci| if (c_ci == s_ci) break :y_pos;
        const c_ll = getAirAmbiance(c_data, c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    z_pos: {
        const z = pos[2] + 1;
        if (z >= chunk.chunkDim) break :z_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
        if (c_ci >= chunk.chunkSize) std.debug.panic("invalid z_pos >= chunk size", .{});
        if (source_ci) |s_ci| if (c_ci == s_ci) break :z_pos;
        const c_ll = getAirAmbiance(c_data, c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    z_neg: {
        const z = pos[2] - 1;
        if (z < 0) break :z_neg;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
        if (source_ci) |s_ci| if (c_ci == s_ci) break :z_neg;
        const c_ll = getAirAmbiance(c_data, c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    return ll;
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
