const std = @import("std");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const config = @import("config");
const blecs = @import("blecs/blecs.zig");
const gfx = @import("gfx/gfx.zig");
const game = @import("game.zig");
const block = @import("block.zig");
const game_state = @import("state.zig");

pub const chunkDim = 64;
pub const chunkSize: comptime_int = chunkDim * chunkDim * chunkDim;
const drawSize = chunkDim * chunkDim;
const minVoxelsInMesh = 1;

const air: u8 = 0;

pub const worldPosition = struct {
    x: u32,
    y: u32,
    z: u32,
    pub fn initFromPositionV(p: @Vector(4, f32)) worldPosition {
        const x = @as(u32, @bitCast(p[0]));
        const y = @as(u32, @bitCast(p[1]));
        const z = @as(u32, @bitCast(p[2]));
        return worldPosition{
            .x = x,
            .y = y,
            .z = z,
        };
    }
    pub fn vecFromWorldPosition(self: worldPosition) @Vector(4, f32) {
        const x = @as(f32, @bitCast(self.x));
        const y = @as(f32, @bitCast(self.y));
        const z = @as(f32, @bitCast(self.z));
        return .{ x, y, z, 0 };
    }
    pub fn equal(self: worldPosition, other: worldPosition) bool {
        return self.x == other.x and self.y == other.y and self.x == other.x;
    }

    // Get adjacent chunk world positions:
    pub fn getFrontWP(self: worldPosition) worldPosition {
        const p = self.vecFromWorldPosition();
        return initFromPositionV(.{ p[0], p[1], p[2] + 1, 0 });
    }
    pub fn getBackWP(self: worldPosition) worldPosition {
        const p = self.vecFromWorldPosition();
        return initFromPositionV(.{ p[0], p[1], p[2] - 1, 0 });
    }
    pub fn getLeftWP(self: worldPosition) worldPosition {
        const p = self.vecFromWorldPosition();
        return initFromPositionV(.{ p[0] + 1, p[1], p[2], 0 });
    }
    pub fn getRightWP(self: worldPosition) worldPosition {
        const p = self.vecFromWorldPosition();
        return initFromPositionV(.{ p[0] - 1, p[1], p[2], 0 });
    }
};

pub fn getWorldPositionForWorldLocation(pos: @Vector(4, f32)) worldPosition {
    const chunk_pos = positionFromWorldLocation(pos);
    return worldPosition.initFromPositionV(chunk_pos);
}

pub fn getBlockId(pos: @Vector(4, f32)) dataAtRes {
    const wp = getWorldPositionForWorldLocation(pos);
    const c = game.state.blocks.game_chunks.get(wp) orelse return .{ .read = true, .data = 0 };
    const chunk_local_pos = chunkPosFromWorldLocation(pos);
    const chunk_index = getIndexFromPositionV(chunk_local_pos);
    return c.dataAt(chunk_index);
}

// setBlockId is not perfectly thread safe as chunk configs are not locked. So
// game.state.ui.data.world_chunk_table_data should not be written to by another thread.
// The copy job does read from this table. Should be fine? :O
// Any updates must trigger an update within the same thread when done setting block ids on chunks.
pub fn setBlockId(pos: @Vector(4, f32), block_id: u8) worldPosition {
    const wp = getWorldPositionForWorldLocation(pos);
    const chunk_local_pos = chunkPosFromWorldLocation(pos);
    const chunk_index = getIndexFromPositionV(chunk_local_pos);
    // Get chunk from chunk state map:
    var bd: block.BlockData = undefined;
    var c = game.state.blocks.game_chunks.get(wp) orelse {
        // Chunk not previously generated, but maybe we already updated it before generating:
        var ch_cfg: game_state.chunkConfig = game.state.ui.data.world_chunk_table_data.get(wp) orelse {
            var cr: [chunkSize]u32 = [_]u32{0} ** chunkSize;
            cr[chunk_index] = block_id;
            const cd: []u32 = game.state.allocator.alloc(u32, cr.len) catch @panic("OOM");
            @memcpy(cd, &cr);
            const new_ch_cfg: game_state.chunkConfig = .{
                .id = 0,
                .scriptId = 0,
                .chunkData = cd,
            };
            game.state.ui.data.world_chunk_table_data.put(wp, new_ch_cfg) catch @panic("OOM");
            return wp;
        };
        bd = block.BlockData.fromId(block_id);
        // no chunk, assume fully lit chunk.
        bd.setFullAmbiance(block.BlockLighingLevel.full);
        // TODO: need to check surrounding lighting
        // Was previously updated, but not generated, just update the table.
        ch_cfg.chunkData[chunk_index] = bd.toId();
        return wp;
    };
    const c_data = game.state.allocator.alloc(u32, chunkSize) catch @panic("OOM");
    defer game.state.allocator.free(c_data);
    {
        c.mutex.lock();
        defer c.mutex.unlock();
        @memcpy(c_data, c.data);
    }

    bd = block.BlockData.fromId(c_data[chunk_index]);
    bd.block_id = block_id;
    c_data[chunk_index] = bd.toId();
    if (block_id == air) {
        set_removed_block_lighting(c_data, chunk_index);
    } else {
        set_added_block_lighting(c_data, &bd, chunk_index);
    }
    {
        c.mutex.lock();
        defer c.mutex.unlock();
        @memcpy(c.data, c_data);
        c.updated = true;
    }
    return wp;
}

pub fn set_removed_block_lighting(c_data: []u32, ci: usize) void {
    const pos = getPositionAtIndexV(ci);
    // Get light from above and see if it's full, have to propagate full all the way down
    y_pos: {
        var c_ci: usize = 0;
        var c_bd: block.BlockData = undefined;
        var y = pos[1] + 1;
        if (y >= chunkDim) {
            y = chunkDim - 1;
            // Assume full light for now for missing chunk.
        } else {
            c_ci = getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
            if (c_ci >= chunkSize) std.debug.panic("invalid y_pos >= chunk size", .{});
            c_bd = block.BlockData.fromId((c_data[c_ci]));
            // Only if the block above is air and full
            if (c_bd.block_id != air) break :y_pos;
            const c_ll = c_bd.getFullAmbiance();
            if (c_ll != .full) {
                std.debug.print("removed block light above wasn't full light {d}\n", .{y});
                break :y_pos;
            }
        }
        while (y >= 0) : (y -= 1) {
            // let the light fall
            c_ci = getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
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
                if (x >= chunkDim) break :x_pos;
                c_ci = getIndexFromPositionV(.{ x, y, pos[2], pos[3] });
                if (c_ci >= chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.left, .full);
                    c_data[c_ci] = c_bd.toId();
                } else set_propagated_lighting(c_data, c_ci);
            }
            x_neg: {
                const x = pos[0] - 1;
                if (x >= chunkDim) break :x_neg;
                c_ci = getIndexFromPositionV(.{ x, y, pos[2], pos[3] });
                if (c_ci >= chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.right, .full);
                    c_data[c_ci] = c_bd.toId();
                } else set_propagated_lighting(c_data, c_ci);
            }
            z_pos: {
                const z = pos[2] + 1;
                if (z >= chunkDim) break :z_pos;
                c_ci = getIndexFromPositionV(.{ pos[0], y, z, pos[3] });
                if (c_ci >= chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.front, .full);
                    c_data[c_ci] = c_bd.toId();
                } else set_propagated_lighting(c_data, c_ci);
            }
            z_neg: {
                const z = pos[2] - 1;
                if (z >= chunkDim) break :z_neg;
                c_ci = getIndexFromPositionV(.{ pos[0], y, z, pos[3] });
                if (c_ci >= chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.back, .full);
                    c_data[c_ci] = c_bd.toId();
                } else set_propagated_lighting(c_data, c_ci);
            }
        }
        std.debug.print("unreachable.\n", .{});
        return;
    }
    std.debug.print("removed block is propagating \n", .{});
    set_propagated_lighting(c_data, ci);
}

pub fn set_added_block_lighting(c_data: []u32, bd: *block.BlockData, ci: usize) void {
    const pos = getPositionAtIndexV(ci);
    std.debug.print("adding block {d} {d} {d}\n", .{
        pos[0],
        pos[1],
        pos[2],
    });
    // set added block surfaces first
    set_surfaces_from_ambient(c_data, bd, ci);

    // If the block above was full lighting all light below has to be dimmed and propagated
    y_pos: {
        var c_ci: usize = 0;
        var c_bd: block.BlockData = undefined;
        var y = pos[1] - 1;
        if (y < 0) {
            // TODO: propagate to chunk below
            break :y_pos;
        }
        c_ci = getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
        const c_ll: block.BlockLighingLevel = get_ambience_from_adjecent(c_data, c_ci, ci);
        std.debug.print("setting the darkness to {}\n", .{c_ll});
        while (y >= 0) : (y -= 1) {
            // let the darkness fall
            c_ci = getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
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
                if (x >= chunkDim) break :x_pos;
                c_ci = getIndexFromPositionV(.{ x, y, pos[2], pos[3] });
                if (c_ci >= chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.left, c_ll);
                    c_data[c_ci] = c_bd.toId();
                } else set_propagated_lighting(c_data, c_ci);
            }
            x_neg: {
                const x = pos[0] - 1;
                if (x >= chunkDim) break :x_neg;
                c_ci = getIndexFromPositionV(.{ x, y, pos[2], pos[3] });
                if (c_ci >= chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.right, c_ll);
                    c_data[c_ci] = c_bd.toId();
                } else set_propagated_lighting(c_data, c_ci);
            }
            z_pos: {
                const z = pos[2] + 1;
                if (z >= chunkDim) break :z_pos;
                c_ci = getIndexFromPositionV(.{ pos[0], y, z, pos[3] });
                if (c_ci >= chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.front, c_ll);
                    c_data[c_ci] = c_bd.toId();
                } else set_propagated_lighting(c_data, c_ci);
            }
            z_neg: {
                const z = pos[2] - 1;
                if (z >= chunkDim) break :z_neg;
                c_ci = getIndexFromPositionV(.{ pos[0], y, z, pos[3] });
                if (c_ci >= chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
                c_bd = block.BlockData.fromId(c_data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.back, c_ll);
                    c_data[c_ci] = c_bd.toId();
                } else set_propagated_lighting(c_data, c_ci);
            }
        }
        std.debug.panic("not reachable", .{});
    }
}

pub fn set_surfaces_from_ambient(c_data: []u32, bd: *block.BlockData, ci: usize) void {
    bd.setFullAmbiance(.none);
    const pos = getPositionAtIndexV(ci);
    x_pos: {
        const x = pos[0] + 1;
        if (x >= chunkDim) break :x_pos;
        const c_ci = getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
        if (c_ci >= chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
        lightCheckDimensional(c_data, c_ci, bd, .right);
    }
    x_neg: {
        const x = pos[0] - 1;
        if (x < 0) break :x_neg;
        const c_ci = getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
        lightCheckDimensional(c_data, c_ci, bd, .left);
    }
    y_pos: {
        const y = pos[1] + 1;
        if (y >= chunkDim) break :y_pos;
        const c_ci = getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
        lightCheckDimensional(c_data, c_ci, bd, .top);
    }
    y_neg: {
        const y = pos[1] - 1;
        if (y < 0) break :y_neg;
        const c_ci = getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
        lightCheckDimensional(c_data, c_ci, bd, .bottom);
    }
    z_pos: {
        const z = pos[2] + 1;
        if (z >= chunkDim) break :z_pos;
        const c_ci = getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
        if (c_ci >= chunkSize) std.debug.panic("invalid z_pos >= chunk size", .{});
        lightCheckDimensional(c_data, c_ci, bd, .back);
    }
    z_neg: {
        const z = pos[2] - 1;
        if (z < 0) break :z_neg;
        const c_ci = getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
        lightCheckDimensional(c_data, c_ci, bd, .front);
    }
    c_data[ci] = bd.toId();
}

// source_ci - when we want brightness from any block other than the one queried from
pub fn get_ambience_from_adjecent(c_data: []u32, ci: usize, source_ci: ?usize) block.BlockLighingLevel {
    const pos = getPositionAtIndexV(ci);
    // now update adjacent
    var ll: block.BlockLighingLevel = .none;
    x_pos: {
        const x = pos[0] + 1;
        if (x >= chunkDim) break :x_pos;
        const c_ci = getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
        if (source_ci) |s_ci| if (c_ci == s_ci) break :x_pos;
        if (c_ci >= chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
        const c_ll = getAirAmbiance(c_data, c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    x_neg: {
        const x = pos[0] - 1;
        if (x < 0) break :x_neg;
        const c_ci = getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
        if (source_ci) |s_ci| if (c_ci == s_ci) break :x_neg;
        const c_ll = getAirAmbiance(c_data, c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    y_pos: {
        const y = pos[1] + 1;
        if (y >= chunkDim) break :y_pos;
        const c_ci = getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
        if (c_ci >= chunkSize) std.debug.panic("invalid y_pos >= chunk size", .{});
        if (source_ci) |s_ci| if (c_ci == s_ci) break :y_pos;
        const c_ll = getAirAmbiance(c_data, c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    z_pos: {
        const z = pos[2] + 1;
        if (z >= chunkDim) break :z_pos;
        const c_ci = getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
        if (c_ci >= chunkSize) std.debug.panic("invalid z_pos >= chunk size", .{});
        if (source_ci) |s_ci| if (c_ci == s_ci) break :z_pos;
        const c_ll = getAirAmbiance(c_data, c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    z_neg: {
        const z = pos[2] - 1;
        if (z < 0) break :z_neg;
        const c_ci = getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
        if (source_ci) |s_ci| if (c_ci == s_ci) break :z_neg;
        const c_ll = getAirAmbiance(c_data, c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    return ll;
}

const max_propagation_distance: u8 = 3;

// This just fixes the lighting for each block as it should be without any context as
// to what else has changed. It doesn't rain down light or shadow. If nothing changed
// it stops. If something changed and its air it propagates more until things stop changing.
pub fn set_propagated_lighting(c_data: []u32, ci: usize) void {
    set_propagated_lighting_neg(c_data, ci, 0);
    set_propagated_lighting_pos(c_data, ci, 0);

    const pos = getPositionAtIndexV(ci);
    const bd: block.BlockData = block.BlockData.fromId(c_data[ci]);
    if (bd.block_id != air) return;
    y_neg: {
        const y = pos[1] - 1;
        if (y < 0) break :y_neg;
        const c_ci = getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
        set_propagated_lighting(c_data, c_ci);
    }
}

pub fn set_propagated_lighting_neg(c_data: []u32, ci: usize, distance: u8) void {
    if (distance >= max_propagation_distance) return;
    const pos = getPositionAtIndexV(ci);
    var bd: block.BlockData = block.BlockData.fromId(c_data[ci]);

    if (bd.block_id == air) {
        var ll = get_ambience_from_adjecent(c_data, ci, null);
        const ty = pos[1] + 1;
        if (ty < chunkDim) {
            // if block above is air just set this block to that
            const c_ci = getIndexFromPositionV(.{ pos[0], ty, pos[2], pos[3] });
            if (c_ci >= chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
            const c_bd: block.BlockData = block.BlockData.fromId(c_data[c_ci]);
            if (c_bd.block_id == air) ll = c_bd.getFullAmbiance();
        } else {
            ll = .full;
        }
        std.debug.print("propagating the light neg {} {d} {d} {d}\n", .{
            ll,
            pos[0],
            pos[1],
            pos[2],
        });
        // if air set full ambience and if changed propagate changes to adjacent and down
        bd.setFullAmbiance(ll);
        c_data[ci] = bd.toId();
        x_neg: {
            const x = pos[0] - 1;
            if (x < 0) break :x_neg;
            const c_ci = getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
            set_propagated_lighting_neg(c_data, c_ci, distance + 1);
        }
        z_neg: {
            const z = pos[2] - 1;
            if (z < 0) break :z_neg;
            const c_ci = getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
            set_propagated_lighting_neg(c_data, c_ci, distance + 1);
        }
        return;
    }
    // non-air just set surfaces of this block
    set_surfaces_from_ambient(c_data, &bd, ci);
}

pub fn set_propagated_lighting_pos(c_data: []u32, ci: usize, distance: u8) void {
    if (distance >= max_propagation_distance) return;
    const pos = getPositionAtIndexV(ci);
    var bd: block.BlockData = block.BlockData.fromId(c_data[ci]);

    if (bd.block_id == air) {
        var ll = get_ambience_from_adjecent(c_data, ci, null);
        const ty = pos[1] + 1;
        if (ty < chunkDim) {
            // if block above is air just set this block to that
            const c_ci = getIndexFromPositionV(.{ pos[0], ty, pos[2], pos[3] });
            if (c_ci >= chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
            const c_bd: block.BlockData = block.BlockData.fromId(c_data[c_ci]);
            if (c_bd.block_id == air) ll = c_bd.getFullAmbiance();
        } else {
            ll = .full;
        }
        std.debug.print("propagating the light pos {} {d} {d} {d}\n", .{
            ll,
            pos[0],
            pos[1],
            pos[2],
        });
        // if air set full ambience and if changed propagate changes to adjacent and down
        bd.setFullAmbiance(ll);
        c_data[ci] = bd.toId();
        x_pos: {
            const x = pos[0] + 1;
            if (x >= chunkDim) break :x_pos;
            const c_ci = getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
            if (c_ci >= chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
            set_propagated_lighting_pos(c_data, c_ci, distance + 1);
        }
        z_pos: {
            const z = pos[2] + 1;
            if (z >= chunkDim) break :z_pos;
            const c_ci = getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
            if (c_ci >= chunkSize) std.debug.panic("invalid z_pos >= chunk size", .{});
            set_propagated_lighting_pos(c_data, c_ci, distance + 1);
        }
        return;
    }
    // non-air just set surfaces of this block
    set_surfaces_from_ambient(c_data, &bd, ci);
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

pub fn positionFromWorldLocation(loc: @Vector(4, f32)) @Vector(4, f32) {
    const cd: f32 = @floatFromInt(chunkDim);
    const changer: @Vector(4, f32) = @splat(cd);
    const p = loc / changer;
    return @floor(p);
}

pub fn chunkPosFromWorldLocation(loc: @Vector(4, f32)) @Vector(4, f32) {
    const cd: f32 = @floatFromInt(chunkDim);
    const changer: @Vector(4, f32) = @splat(cd);
    const p = @mod(loc, changer);
    return @floor(p);
}

pub fn getPositionAtIndexV(i: usize) @Vector(4, f32) {
    const x = @as(f32, @floatFromInt(@mod(i, chunkDim)));
    const y = @as(f32, @floatFromInt(@mod(i / chunkDim, chunkDim)));
    const z = @as(f32, @floatFromInt(i / (chunkDim * chunkDim)));
    return @Vector(4, f32){ x, y, z, 0 };
}

pub fn getIndexFromPositionV(p: @Vector(4, f32)) usize {
    const x = @as(u32, @intFromFloat(p[0]));
    const y = @as(u32, @intFromFloat(p[1]));
    const z = @as(u32, @intFromFloat(p[2]));
    return @as(
        usize,
        @intCast(@mod(x, chunkDim) + @mod(y, chunkDim) * chunkDim + @mod(z, chunkDim) * chunkDim * chunkDim),
    );
}

pub const dataAtRes = struct {
    read: bool = false,
    data: u32 = 0,
};

pub const Chunk = struct {
    wp: worldPosition,
    entity: blecs.ecs.entity_t = 0,
    data: []u32 = undefined,
    allocator: std.mem.Allocator,
    attr_builder: ?*gfx.buffer_data.AttributeBuilder = null,
    indices: ?[]u32 = null,
    draws: ?[]c_int = null,
    draw_offsets: ?[]c_int = null, // this only exists to hold the values that draw_offsets_gl points to...
    draw_offsets_gl: ?[]?*const anyopaque = null,
    prev_draw_offsets_gl: ?[]?*const anyopaque = null,
    prev_draws: ?[]c_int = null,
    is_settings: bool = false,
    updated: bool = false,
    vbo: u32 = 0,
    mutex: std.Thread.Mutex = .{},
    // Lock mesh jobs from spawning while one is on going.
    mesh_mutex: std.Thread.Mutex = .{},
    pub fn init(
        allocator: std.mem.Allocator,
        wp: worldPosition,
        entity: blecs.ecs.entity_t,
        is_settings: bool,
    ) !*Chunk {
        const c: *Chunk = try allocator.create(Chunk);
        c.* = Chunk{
            .wp = wp,
            .entity = entity,
            .allocator = allocator,
            .is_settings = is_settings,
        };
        return c;
    }

    pub fn dataAt(self: *Chunk, i: usize) dataAtRes {
        if (!self.mutex.tryLock()) {
            return .{ .read = false, .data = 0 };
        }
        defer self.mutex.unlock();
        return .{ .read = true, .data = self.data[i] };
    }

    pub fn refreshRender(self: *Chunk, world: *blecs.ecs.world_t) void {
        const render_entity = blecs.ecs.get_target(
            world,
            self.entity,
            blecs.entities.block.HasChunkRenderer,
            0,
        );
        _ = game.state.jobs.meshChunk(world, render_entity, self);
    }

    pub fn deinit(self: *Chunk) void {
        self.deinitRenderData();
        self.deinitRenderPreviousData();
        self.allocator.free(self.data);
        if (self.attr_builder) |b| b.deinit();
        if (self.indices) |i| self.allocator.free(i);
    }

    pub fn backupDrawsData(self: *Chunk) void {
        self.deinitRenderPreviousData();
        self.prev_draws = self.draws;
        self.prev_draw_offsets_gl = self.draw_offsets_gl;
    }

    pub fn deinitRenderData(self: *Chunk) void {
        self.backupDrawsData();
        if (self.draw_offsets) |d| self.allocator.free(d);
        self.draw_offsets = null;
        self.draws = null;
        self.draw_offsets_gl = null;
    }

    pub fn deinitRenderPreviousData(self: *Chunk) void {
        if (self.prev_draw_offsets_gl) |d| self.allocator.free(d);
        self.prev_draw_offsets_gl = null;
        if (self.prev_draws) |d| self.allocator.free(d);
        self.prev_draws = null;
    }

    // findMeshes - calling context owns the resulting hash map and needs to free it.
    pub fn findMeshes(self: *Chunk) !std.AutoHashMap(usize, @Vector(4, f32)) {
        if (config.use_tracy) {
            const tracy_zone = ztracy.ZoneNC(@src(), "ChunkMeshing", 0x00_00_f0_f0);
            defer tracy_zone.End();
            var chunker = try Chunker.init(self);
            defer chunker.deinit();
            try chunker.run();
            return chunker.meshes;
        } else {
            var chunker = try Chunker.init(self);
            defer chunker.deinit();
            try chunker.run();
            return chunker.meshes;
        }
    }
};

pub const Chunker = struct {
    chunk: *Chunk,
    numVoxelsInMesh: usize,
    currentVoxel: usize,
    currentScale: @Vector(4, f32),
    toBeMeshed: [minVoxelsInMesh]usize,
    cachingMeshed: bool,
    meshed: [chunkSize]bool,
    meshes: std.AutoHashMap(usize, @Vector(4, f32)),

    pub fn init(chunk: *Chunk) !Chunker {
        // chunkSize
        return Chunker{
            .chunk = chunk,
            .numVoxelsInMesh = 0,
            .currentVoxel = 0,
            .currentScale = .{ 1, 1, 1, 0 },
            .toBeMeshed = [_]usize{0} ** minVoxelsInMesh,
            .cachingMeshed = true,
            .meshed = [_]bool{false} ** chunkSize,
            .meshes = std.AutoHashMap(usize, @Vector(4, f32)).init(chunk.allocator),
        };
    }

    pub fn deinit(_: *Chunker) void {}

    fn updateMeshed(self: *Chunker, i: usize) !void {
        if (self.numVoxelsInMesh < minVoxelsInMesh) {
            self.toBeMeshed[self.numVoxelsInMesh] = i;
            self.numVoxelsInMesh += 1;
            return;
        }
        if (self.cachingMeshed) {
            for (self.toBeMeshed) |ii| {
                self.meshed[ii] = true;
            }
            self.cachingMeshed = false;
            self.toBeMeshed = [_]usize{0} ** minVoxelsInMesh;
        }
        self.meshed[i] = true;
    }

    fn updateChunk(self: *Chunker) !void {
        try self.meshes.put(self.currentVoxel, self.currentScale);
        self.toBeMeshed = [_]usize{0} ** minVoxelsInMesh;
        self.numVoxelsInMesh = 0;
        self.initScale();
        self.cachingMeshed = true;
    }

    fn initScale(self: *Chunker) void {
        self.currentScale = .{ 1, 1, 1, 0 };
    }

    pub fn run(self: *Chunker) !void {
        var op: @Vector(4, f32) = .{ 0, 0, 0, 0 };
        var p = op;
        p[0] += 1;
        var i: usize = 0;
        var firstLoop = true;
        outer: while (true) {
            var numDimsTravelled: u8 = 1;
            while (true) {
                if (firstLoop) {
                    // first loop, skip iterating
                    firstLoop = false;
                    break;
                }
                i += 1;
                if (i >= chunkSize) {
                    break :outer;
                }
                op = getPositionAtIndexV(i);
                p = op;
                if (p[0] + 1 < chunkDim) {
                    p[0] += 1;
                    break;
                }
                if (p[1] + 1 < chunkDim) {
                    numDimsTravelled = 2;
                    p[1] += 1;
                    break;
                }
                if (p[2] + 1 < chunkDim) {
                    numDimsTravelled = 3;
                    p[2] += 1;
                    break;
                }
                continue;
            }
            const blockId = self.chunk.data[i];
            if (blockId & 0x00_000_00F == 0) {
                continue :outer;
            }
            if (self.meshed[i]) {
                continue :outer;
            }
            self.currentVoxel = i;
            var endX: f32 = op[0];
            var endY: f32 = op[1];
            var numXAdded: f32 = 0;
            var numYAdded: f32 = 0;
            inner: while (true) {
                if (numDimsTravelled == 1) {
                    const ii = getIndexFromPositionV(p);
                    if (blockId != self.chunk.data[ii] or self.meshed[ii]) {
                        numDimsTravelled += 1;
                        p[0] = op[0];
                        p[1] += 1;
                        p[2] = op[2]; // Happens when near chunkDims
                        continue :inner;
                    }
                    if (numXAdded == 0) {
                        numXAdded += 1;
                        try self.updateMeshed(i);
                    }
                    try self.updateMeshed(ii);
                    endX = p[0];
                    self.currentScale[0] = endX - op[0] + 1;
                    p[0] += 1;
                    if (p[0] >= chunkDim) {
                        numDimsTravelled += 1;
                        p[1] += 1;
                        p[0] = op[0];
                        continue :inner;
                    }
                    numXAdded += 1;
                } else if (numDimsTravelled == 2) {
                    if (p[1] >= chunkDim) {
                        p[1] = op[1];
                        p[2] += 1;
                        numDimsTravelled += 1;
                        continue :inner;
                    }
                    const ii = getIndexFromPositionV(p);
                    // doing y here, only add if all x along the y are the same
                    if (blockId != self.chunk.data[ii] or self.meshed[ii]) {
                        p[0] = op[0];
                        p[1] = op[1];
                        p[2] += 1;
                        if (p[2] >= chunkDim) {
                            break :inner;
                        }
                        numDimsTravelled += 1;
                        continue :inner;
                    }
                    if (numYAdded == 0) {
                        try self.updateMeshed(i);
                    }
                    if (p[0] != endX) {
                        p[0] += 1;
                        continue :inner;
                    }
                    // need to add all x's along the y to meshed map
                    const _beg = @as(usize, @intFromFloat(op[0]));
                    const _end = @as(usize, @intFromFloat(endX)) + 1;
                    for (_beg.._end) |xToAdd| {
                        const _xToAdd = @as(f32, @floatFromInt(xToAdd));
                        const np: @Vector(4, f32) = .{ _xToAdd, p[1], p[2], 0 };
                        const iii = getIndexFromPositionV(np);
                        if (self.chunk.data[iii] != 0) try self.updateMeshed(iii);
                    }
                    numYAdded += 1;
                    endY = p[1];
                    self.currentScale[1] = endY - op[1] + 1;
                    p[1] += 1;
                    p[0] = op[0];
                } else {
                    const ii = getIndexFromPositionV(p);
                    if (blockId != self.chunk.data[ii]) {
                        break :inner;
                    }
                    if (self.meshed[ii]) {
                        break :inner;
                    }
                    if (p[0] != endX) {
                        p[0] += 1;
                        continue :inner;
                    }
                    if (p[1] != endY) {
                        p[1] += 1;
                        p[0] = op[0];
                        continue :inner;
                    }
                    // need to add all x's along the y to meshed map
                    const _begX = @as(usize, @intFromFloat(op[0]));
                    const _endX = @as(usize, @intFromFloat(endX)) + 1;
                    for (_begX.._endX) |xToAdd| {
                        const _xToAdd = @as(f32, @floatFromInt(xToAdd));
                        const _begY = @as(usize, @intFromFloat(op[1]));
                        const _endY = @as(usize, @intFromFloat(endY)) + 1;
                        for (_begY.._endY) |yToAdd| {
                            const _yToAdd = @as(f32, @floatFromInt(yToAdd));
                            const iii = getIndexFromPositionV(.{ _xToAdd, _yToAdd, p[2], 0 });
                            // a one off bug I think?
                            if (self.chunk.data[iii] != 0) try self.updateMeshed(iii);
                        }
                    }
                    self.currentScale[2] = p[2] - op[2] + 1;
                    p[2] += 1;
                    p[0] = op[0];
                    p[1] = op[1];
                    if (p[2] >= chunkDim) {
                        break :inner;
                    }
                    continue :inner;
                }
            }
            try self.updateChunk();
        }
        // check final voxel:
        i = getIndexFromPositionV(.{ 63, 63, 63, 0 });
        const blockId = self.chunk.data[i];
        if (blockId & 0x00_000_00F == 0) {
            return;
        }
        if (self.meshed[i]) {
            return;
        }
        self.meshed[i] = true;
        self.meshes.put(i, .{ 1, 1, 1, 1 }) catch @panic("OOM");
    }
};
