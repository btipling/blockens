const air: u8 = 0;
const max_propagation_distance: u8 = 3;

pub const Lighting = @This();

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
    self.darken_area_around_block(ci);
    self.light_fall_around_block(ci);
    self.determine_air_ambience_around_block(ci);
    self.determine_block_ambience_around_block(ci);
}

pub fn set_added_block_lighting(self: *Lighting, _: *block.BlockData, ci: usize) void {
    self.darken_area_around_block(ci);
    self.light_fall_around_block(ci);
    self.determine_air_ambience_around_block(ci);
    self.determine_block_ambience_around_block(ci);
}

pub fn darken_area_around_block(self: *Lighting, ci: usize) void {
    const pos = chunk.getPositionAtIndexV(ci);
    var is_multi_chunk = self.pos[1] == 1;
    // go 2 positions up and 2 positions out in every direction and nuke the light
    // in a 5x5x5 cube starting at the top going down and everything beneath the cube until
    // a surface is hit
    // then starting at the top, figure out what the ambient lighting should be for each
    // going down

    // go up 2 or as far as we can
    var y = pos[1];
    while (y < chunk.chunkDim and y < pos[1] + 2) : (y += 1) {}
    // go out x znd z by 2 or as far as we can
    var x = pos[0];
    while (x > 0 and x > pos[0] - 2) : (x -= 2) {}
    var z = pos[0];
    while (z > 0 and z > pos[2] - 2) : (z -= 2) {}
    // set ends in the x and z direction
    var y_end = y;
    while (y_end > 0 and y_end > y - 5) : (y_end -= 1) {} // y goes down
    var x_end = x;
    while (x_end < chunk.chunkDim and x_end < x + 5) : (x_end += 1) {}
    var z_end = z;
    while (z_end < chunk.chunkDim and z_end < z + 5) : (z_end += 1) {}
    // shut out the lights
    var y_d = y;
    var x_d = x;
    var z_d = z;
    std.debug.print("y: {d}, x: {d}, z: {d} - end_y: {d}, end_x: {d}, end_z: {d}\n", .{
        y_d,
        x_d,
        z_d,
        y_end,
        x_end,
        z_end,
    });
    while (y_d >= y_end) : (y_d -= 1) {
        while (x_d < x_end) : (x_d += 1) {
            while (z_d < z_end) : (z_d += 1) {
                const c_ci = chunk.getIndexFromPositionV(.{ x_d, y_d, z_d, 0 });
                var data = self.get_datas(self.wp) orelse continue;
                var c_bd: block.BlockData = block.BlockData.fromId(data[c_ci]);
                c_bd.ambient = 0;
                data[c_ci] = c_bd.toId();
            }
            z_d = z;
        }
        x_d = x;
    }
    // now darken each x, z from y_end until a surface is hit:
    y_d = y_end;
    x_d = x;
    z_d = z;

    var wp = self.wp;
    while (x_d < x_end) : (x_d += 1) {
        while (z_d < z_end) : (z_d += 1) {
            while (true) {
                const c_ci = chunk.getIndexFromPositionV(.{ x_d, y_d, z_d, 0 });
                var data = self.get_datas(wp) orelse continue;
                var c_bd: block.BlockData = block.BlockData.fromId(data[c_ci]);
                if (c_bd.block_id != air) {
                    c_bd.setAmbient(.top, .none);
                    data[c_ci] = c_bd.toId();
                    break;
                }
                c_bd.ambient = 0;
                data[c_ci] = c_bd.toId();
                if (y_d == 0) {
                    if (is_multi_chunk) {
                        wp = wp.getBelowWP();
                        y_d = 63;
                        is_multi_chunk = false;
                    } else break;
                } else y_d -= 1;
            }
            wp = self.wp;
            y_d = y_end;
        }
        z_d = z;
    }
}

pub fn light_fall_around_block(self: *Lighting, ci: usize) void {
    const pos = chunk.getPositionAtIndexV(ci);
    var is_multi_chunk = self.pos[1] == 1;
    // drop light from top

    // go up 2 or as far as we can
    var y = pos[1];
    while (y < chunk.chunkDim and y < pos[1] + 2) : (y += 1) {}
    // go out x znd z by 2 or as far as we can
    var x = pos[0];
    while (x > 0 and x > pos[0] - 2) : (x -= 2) {}
    var z = pos[0];
    while (z > 0 and z > pos[2] - 2) : (z -= 2) {}
    // set ends in the x and z direction
    var y_end = y;
    while (y_end > 0 and y_end > y - 5) : (y_end -= 1) {} // y goes down
    var x_end = x;
    while (x_end < chunk.chunkDim and x_end < x + 5) : (x_end += 1) {}
    var z_end = z;
    while (z_end < chunk.chunkDim and z_end < z + 5) : (z_end += 1) {}
    var y_d = y;
    var x_d = x;
    var z_d = z;
    std.debug.print("y: {d}, x: {d}, z: {d} - end_y: {d}, end_x: {d}, end_z: {d}\n", .{
        y_d,
        x_d,
        z_d,
        y_end,
        x_end,
        z_end,
    });
    var wp = self.wp;
    while (x_d < x_end) : (x_d += 1) {
        while (z_d < z_end) : (z_d += 1) {
            while (true) {
                var data = self.get_datas(wp) orelse break;
                var ll: block.BlockLighingLevel = .full;
                // Look one up to get light to drop.
                if (y_d + 1 < chunk.chunkDim) {
                    const u_ci = chunk.getIndexFromPositionV(.{ x_d, y_d + 1, z_d, 0 });
                    const u_bd: block.BlockData = block.BlockData.fromId(data[u_ci]);
                    if (u_bd.block_id != air) break; // No light falling here.
                    ll = u_bd.getFullAmbiance();
                }
                const c_ci = chunk.getIndexFromPositionV(.{ x_d, y_d, z_d, 0 });
                var c_bd: block.BlockData = block.BlockData.fromId(data[c_ci]);
                if (c_bd.block_id != air) break; // All done dropping light.
                c_bd.setFullAmbiance(ll);
                data[c_ci] = c_bd.toId();
                if (y_d == 0) {
                    if (is_multi_chunk) {
                        wp = wp.getBelowWP();
                        y_d = 63;
                        is_multi_chunk = false;
                    } else break;
                } else y_d -= 1;
            }
            wp = self.wp;
            y_d = y;
        }
        z_d = z;
    }
}

pub fn determine_air_ambience_around_block(self: *Lighting, ci: usize) void {
    const pos = chunk.getPositionAtIndexV(ci);
    var is_multi_chunk = self.pos[1] == 1;
    // find the adjacent air ambiance for non fully ambiant are and propagate it

    // go up 2 or as far as we can
    var y = pos[1];
    while (y < chunk.chunkDim and y < pos[1] + 2) : (y += 1) {}
    // go out x znd z by 2 or as far as we can
    var x = pos[0];
    while (x > 0 and x > pos[0] - 2) : (x -= 2) {}
    var z = pos[0];
    while (z > 0 and z > pos[2] - 2) : (z -= 2) {}
    // set ends in the x and z direction
    var y_end = y;
    while (y_end > 0 and y_end > y - 5) : (y_end -= 1) {} // y goes down
    var x_end = x;
    while (x_end < chunk.chunkDim and x_end < x + 5) : (x_end += 1) {}
    var z_end = z;
    while (z_end < chunk.chunkDim and z_end < z + 5) : (z_end += 1) {}
    // get air ambiance
    var y_d = y;
    var x_d = x;
    var z_d = z;
    std.debug.print("y: {d}, x: {d}, z: {d} - end_y: {d}, end_x: {d}, end_z: {d}\n", .{
        y_d,
        x_d,
        z_d,
        y_end,
        x_end,
        z_end,
    });
    while (y_d >= y_end) : (y_d -= 1) {
        while (x_d < x_end) : (x_d += 1) {
            while (z_d < z_end) : (z_d += 1) {
                const c_ci = chunk.getIndexFromPositionV(.{ x_d, y_d, z_d, 0 });
                var data = self.get_datas(self.wp) orelse continue;
                var c_bd: block.BlockData = block.BlockData.fromId(data[c_ci]);
                if (c_bd.block_id != air) continue;
                if (c_bd.getFullAmbiance() != .none) continue; // already has ambiance
                const ll = self.get_ambience_from_adjecent(c_ci, null);
                c_bd.setFullAmbiance(ll);
                data[c_ci] = c_bd.toId();
            }
            z_d = z;
        }
        x_d = x;
    }
    // now darken each x, z from y_end until a surface is hit:
    y_d = y_end;
    x_d = x;
    z_d = z;

    var wp = self.wp;
    while (x_d < x_end) : (x_d += 1) {
        while (z_d < z_end) : (z_d += 1) {
            while (true) {
                const c_ci = chunk.getIndexFromPositionV(.{ x_d, y_d, z_d, 0 });
                var data = self.get_datas(wp) orelse continue;
                var c_bd: block.BlockData = block.BlockData.fromId(data[c_ci]);
                if (c_bd.block_id != air) break;
                if (c_bd.getFullAmbiance() != .none) break; // already dropped light in this y.
                const ll = self.get_ambience_from_adjecent(c_ci, null);
                c_bd.setFullAmbiance(ll);
                data[c_ci] = c_bd.toId();
                if (y_d == 0) {
                    if (is_multi_chunk) {
                        wp = wp.getBelowWP();
                        y_d = 63;
                        is_multi_chunk = false;
                    } else break;
                } else y_d -= 1;
            }
            wp = self.wp;
            y_d = y_end;
        }
        z_d = z;
    }
}

pub fn determine_block_ambience_around_block(self: *Lighting, ci: usize) void {
    const pos = chunk.getPositionAtIndexV(ci);
    var is_multi_chunk = self.pos[1] == 1;
    // go 2 positions up and 2 positions out in every direction and nuke the light
    // in a 5x5x5 cube starting at the top going down and everything beneath the cube until
    // a surface is hit
    // then starting at the top, figure out what the ambient lighting should be for each
    // going down

    // go up 2 or as far as we can
    var y = pos[1];
    while (y < chunk.chunkDim and y < pos[1] + 2) : (y += 1) {}
    // go out x znd z by 2 or as far as we can
    var x = pos[0];
    while (x > 0 and x > pos[0] - 2) : (x -= 2) {}
    var z = pos[0];
    while (z > 0 and z > pos[2] - 2) : (z -= 2) {}
    // set ends in the x and z direction
    var y_end = y;
    while (y_end > 0 and y_end > y - 5) : (y_end -= 1) {} // y goes down
    var x_end = x;
    while (x_end < chunk.chunkDim and x_end < x + 5) : (x_end += 1) {}
    var z_end = z;
    while (z_end < chunk.chunkDim and z_end < z + 5) : (z_end += 1) {}
    // shut out the lights
    var y_d = y;
    var x_d = x;
    var z_d = z;
    std.debug.print("y: {d}, x: {d}, z: {d} - end_y: {d}, end_x: {d}, end_z: {d}\n", .{
        y_d,
        x_d,
        z_d,
        y_end,
        x_end,
        z_end,
    });
    while (y_d >= y_end) : (y_d -= 1) {
        while (x_d < x_end) : (x_d += 1) {
            while (z_d < z_end) : (z_d += 1) {
                const c_ci = chunk.getIndexFromPositionV(.{ x_d, y_d, z_d, 0 });
                var data = self.get_datas(self.wp) orelse continue;
                var c_bd: block.BlockData = block.BlockData.fromId(data[c_ci]);
                if (c_bd.block_id == air) continue;
                self.set_surfaces_from_ambient(&c_bd, c_ci);
                data[c_ci] = c_bd.toId();
            }
            z_d = z;
        }
        x_d = x;
    }
    // now darken each x, z from y_end until a surface is hit:
    y_d = y_end;
    x_d = x;
    z_d = z;

    var wp = self.wp;
    while (x_d < x_end) : (x_d += 1) {
        while (z_d < z_end) : (z_d += 1) {
            while (true) {
                const c_ci = chunk.getIndexFromPositionV(.{ x_d, y_d, z_d, 0 });
                var data = self.get_datas(wp) orelse continue;
                var c_bd: block.BlockData = block.BlockData.fromId(data[c_ci]);
                if (c_bd.block_id != air) {
                    self.set_surfaces_from_ambient(&c_bd, c_ci);
                    data[c_ci] = c_bd.toId();
                    break;
                }
                if (y_d == 0) {
                    if (is_multi_chunk) {
                        wp = wp.getBelowWP();
                        y_d = 63;
                        is_multi_chunk = false;
                    } else break;
                } else y_d -= 1;
            }
            wp = self.wp;
            y_d = y_end;
        }
        z_d = z;
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
        y_pos: {
            // in case of block above bd, set bot surface to new ll
            const y = pos[1] + 1;
            if (y >= chunk.chunkDim) break :y_pos;
            const t_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
            var t_bd: block.BlockData = block.BlockData.fromId(data[t_ci]);
            if (t_bd.block_id == air) break :y_pos;
            if (t_bd.getSurfaceAmbience(.bottom) != ll) {
                self.propagated[t_ci] = 1;
                t_bd.setAmbient(.bottom, ll);
                data[t_ci] = t_bd.toId();
            }
        }
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
        y_neg: {
            // TODO: this needs to fall
            const y = pos[1] - 1;
            if (y < 0) break :y_neg;
            const c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
            self.set_propagated_lighting_with_distance(c_ci, distance);
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
    var y_p_ll = ll;
    var x_p_ll = ll;
    var x_n_ll = ll;
    var z_p_ll = ll;
    var z_n_ll = ll;
    y_pos: {
        // If above is air we don't darken that brightness.
        const y = pos[1] + 1;
        if (y >= chunk.chunkDim) break :y_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], y, pos[2], pos[3] });
        if (c_ci >= chunk.chunkSize) std.debug.panic("invalid y_pos >= chunk size", .{});
        if (source_ci) |s_ci| if (c_ci == s_ci) break :y_pos;
        const data = self.get_datas(self.wp) orelse break :y_pos;
        const c_bd: block.BlockData = block.BlockData.fromId((data[c_ci]));
        if (c_bd.block_id != air) break :y_pos;
        const c_ll = c_bd.getFullAmbiance();
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
        y_p_ll = c_ll;
    }
    x_pos: {
        const x = pos[0] + 1;
        if (x >= chunk.chunkDim) break :x_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
        if (source_ci) |s_ci| if (c_ci == s_ci) break :x_pos;
        if (c_ci >= chunk.chunkSize) std.debug.panic("invalid x_pos >= chunk size", .{});
        const c_ll = self.getAirAmbiance(c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
        x_p_ll = c_ll;
    }
    x_neg: {
        const x = pos[0] - 1;
        if (x < 0) break :x_neg;
        const c_ci = chunk.getIndexFromPositionV(.{ x, pos[1], pos[2], pos[3] });
        if (source_ci) |s_ci| if (c_ci == s_ci) break :x_neg;
        const c_ll = self.getAirAmbiance(c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
        x_n_ll = c_ll;
    }
    z_pos: {
        const z = pos[2] + 1;
        if (z >= chunk.chunkDim) break :z_pos;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
        if (c_ci >= chunk.chunkSize) std.debug.panic("invalid z_pos >= chunk size", .{});
        if (source_ci) |s_ci| if (c_ci == s_ci) break :z_pos;
        const c_ll = self.getAirAmbiance(c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
        z_p_ll = c_ll;
    }
    z_neg: {
        const z = pos[2] - 1;
        if (z < 0) break :z_neg;
        const c_ci = chunk.getIndexFromPositionV(.{ pos[0], pos[1], z, pos[3] });
        if (source_ci) |s_ci| if (c_ci == s_ci) break :z_neg;
        const c_ll = self.getAirAmbiance(c_ci);
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
        z_n_ll = c_ll;
    }
    if (ll == .dark) {
        std.debug.print("\ndark air @ {d} {d} {d} \n", .{ pos[0], pos[1], pos[2] });
        std.debug.print("y_pos {} \nx_pos {} \nx_neg {} \nz_pos {} \nz_neg {} \n\n", .{
            y_p_ll,
            x_p_ll,
            x_n_ll,
            z_p_ll,
            z_n_ll,
        });
    }
    return ll;
}

test "lighting basic remove block lighting fall" {
    var l: Lighting = testing_utils.utest_chunk_ae_lighting(1);
    defer l.deinit();
    defer l.fetcher.deinit();
    const data = testing_utils.utest_allocate_test_chunk(0, .full);
    defer l.allocator.free(data);

    // set a dark ground floor across y = 0
    testing_utils.utest_add_floor_at_y(data, 0, .none);
    const _x: f32 = 16;
    const _z: f32 = 16;
    const ci = chunk.getIndexFromPositionV(.{ _x, 1, _z, 0 });

    testing_utils.utest_set_block_surface_light(data, ci, .full, .bottom, .none);

    // init l
    l.datas[0] = .{
        .wp = l.wp,
        .data = data,
    };
    // validate the block below placement is dark on the surface
    try testing_utils.utest_expect_surface_light_at_v(data, .{ _x, 0, _z, 0 }, .top, .none);

    var bd: block.BlockData = block.BlockData.fromId(data[ci]);
    bd.block_id = 0;
    data[ci] = bd.toId();
    l.set_removed_block_lighting(ci);

    // validate that the block below's surface is now fully lit
    try testing_utils.utest_expect_surface_light_at_v(data, .{ _x, 0, _z, 0 }, .top, .full);
}

test "lighting adding block across chunks darkness fall" {
    var l: Lighting = testing_utils.utest_chunk_ae_lighting(1);
    defer l.deinit();
    defer l.fetcher.deinit();
    const t_data = testing_utils.utest_allocate_test_chunk(0, .full);
    defer l.allocator.free(t_data);

    const b_wp = chunk.worldPosition.initFromPositionV(.{ 0, 0, 0, 0 });
    {
        // Set a dark and full non air block bottom chunk for fetcher
        const b_data = testing_utils.utest_allocate_test_chunk(1, .none);
        // set a lit ground floor across y = 63 on bottom chunk
        testing_utils.utest_add_floor_at_y(b_data, 63, .full);
        l.fetcher.test_chunk_data.put(b_wp, b_data) catch @panic("OOM");
    }
    const _x: f32 = 16;
    const _z: f32 = 16;
    const ci = chunk.getIndexFromPositionV(.{ _x, 5, _z, 0 });
    // validate the block on the chunk below where placement will occur is fully list on the surface
    {
        const b_data = l.fetcher.test_chunk_data.get(b_wp) orelse @panic("expected bottom wp");
        try testing_utils.utest_expect_surface_light_at_v(b_data, .{ _x, 63, _z, 0 }, .top, .full);
    }
    // Set a block on y, a bit above bottom chunk.
    {
        // Set a block above of the dark ground in y 1:
        var bd: block.BlockData = block.BlockData.fromId(1);
        t_data[ci] = bd.toId();
    }
    var bd: block.BlockData = block.BlockData.fromId(t_data[ci]);
    bd.block_id = 0;
    t_data[ci] = bd.toId();
    // init l
    l.datas[0] = .{
        .wp = l.wp,
        .data = t_data,
    };
    l.set_added_block_lighting(&bd, ci);
    // validate that the block on chunk below's surface is now fully lit
    {
        // expected lighting to have fetched extra data for bottom chunk
        try std.testing.expectEqual(l.num_extra_datas, 1);
        // expected extra data to have been fetchable
        try std.testing.expect(l.datas[1].fetchable);
        const b_data = l.datas[1].data orelse @panic("expected data to be there");
        // bright is one level darker than full.
        try testing_utils.utest_expect_surface_light_at_v(b_data, .{ _x, 63, _z, 0 }, .top, .bright);
    }
}

test "lighting removing block across chunks lighting falls" {
    var l: Lighting = testing_utils.utest_chunk_ae_lighting(1);
    defer l.deinit();
    defer l.fetcher.deinit();
    // set a lit ground floor across y = 63 on bottom chunk
    const t_data = testing_utils.utest_allocate_test_chunk(0, .full);
    defer l.allocator.free(t_data);

    const b_wp = chunk.worldPosition.initFromPositionV(.{ 0, 0, 0, 0 });
    {
        // Set a dark and full non air block bottom chunk for fetcher
        const b_data = testing_utils.utest_allocate_test_chunk(1, .none);
        l.fetcher.test_chunk_data.put(b_wp, b_data) catch @panic("OOM");
    }
    // Set a block on y, just a slight ways above bottom chunk.
    const _x: f32 = 16;
    const _z: f32 = 16;
    const ci = chunk.getIndexFromPositionV(.{ _x, 0, _z, 0 });
    // Set a block on top of the dark ground in y 1:
    testing_utils.utest_set_block_surface_light(t_data, ci, .full, .bottom, .none);
    // init l
    l.datas[0] = .{
        .wp = l.wp,
        .data = t_data,
    };
    // validate the block on the chunk below placement is dark on the surface
    {
        const b_data = l.fetcher.test_chunk_data.get(b_wp) orelse @panic("expected bottom wp");
        try testing_utils.utest_expect_surface_light_at_v(b_data, .{ _x, 63, _z, 0 }, .top, .none);
    }
    var bd: block.BlockData = block.BlockData.fromId(t_data[ci]);
    bd.block_id = 0;
    t_data[ci] = bd.toId();
    l.set_removed_block_lighting(ci);
    // validate that the block on chunk below's surface is now fully lit
    {
        // expected lighting to have fetched extra data for bottom chunk
        try std.testing.expectEqual(l.num_extra_datas, 1);
        // expected extra data to have been fetchable
        try std.testing.expect(l.datas[1].fetchable);
        const b_data = l.datas[1].data orelse @panic("expected data to be there");
        try testing_utils.utest_expect_surface_light_at_v(b_data, .{ _x, 63, _z, 0 }, .top, .full);
    }
}

test "lighting plane building surface test" {
    // iteratively build a plane and ensure it behaves correctly
    const plane_pos: @Vector(4, f32) = .{ 10, 4, 10, 0 };
    const plane_dim: usize = 5;
    const floor_y: f32 = 63; // on bottom chunk
    _ = floor_y;

    // All the expected lightings per iteration

    // both bottom of top plane and top of below surface should be like this.
    // zig fmt: off
    const expected_lighting: [25][5][5]?block.BlockLighingLevel = .{
        // 0
        .{
            .{ .bright, null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 1
        .{
            .{ .bright, .bright, null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 2
        .{
            .{ .bright, .bright, .bright, null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 3
        .{
            .{ .bright, .bright, .bright, .bright, null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 4
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 5
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 6
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .bright, null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 7
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .bright, .bright, null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 8
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .bright, .bright, .bright, null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 9
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 10
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 11
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .dark,   .bright, .bright, .bright },
            .{ .bright, .bright, null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 12
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .dark,   .dark,   .bright, .bright },
            .{ .bright, .bright, .bright, null,    null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 13
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .bright, .bright, .bright, null    },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 14
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ null,    null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 15
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, null,    null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 16
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .dark,   .bright, .bright, .bright },
            .{ .bright, .bright, null,    null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 17
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .dark,   .dark,   .bright, .bright },
            .{ .bright, .bright, .bright, null,    null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 18
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .bright, .bright, .bright, null    },
            .{ null,    null,    null,    null,    null    },
        },
        // 19
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ null,    null,    null,    null,    null    },
        },
        // 20
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, null,    null,    null,    null    },
        },
        // 21
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .dark,   .bright, .bright, .bright },
            .{ .bright, .bright, null,    null,    null    },
        },
        // 22
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .dark,   .none,   .dark,   .bright },
            .{ .bright, .dark,   .bright, .bright, .bright },
            .{ .bright, .bright, .bright,  null,    null   },
        },
        // 23
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .dark,   .none,   .dark,   .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .bright, .bright, .bright, null },
        },
        // 24
        .{
            .{ .bright, .bright, .bright, .bright, .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .dark,   .none,   .dark,   .bright },
            .{ .bright, .dark,   .dark,   .dark,   .bright },
            .{ .bright, .bright, .bright, .bright, .bright },
        },
    };
    // zig fmt: on
    const t_base_data = testing_utils.utest_allocate_test_chunk(0, .full);
    defer std.testing.allocator.free(t_base_data);
    const b_base_data = testing_utils.utest_allocate_test_chunk(1, .none);
    // set a lit ground floor across y = 63 on bottom chunk
    testing_utils.utest_add_floor_at_y(b_base_data, 63, .full);
    defer std.testing.allocator.free(b_base_data);

    var test_case: usize = 0;
    const block_id = 1;
    var _x: usize = 0;
    while (_x < plane_dim) : (_x += 1) {
        var _z: usize = 0;
        while (_z < plane_dim) : (_z += 1) {
            var l: Lighting = testing_utils.utest_chunk_ae_lighting(1);
            defer l.deinit();
            defer l.fetcher.deinit();
            // set a lit ground floor across y = 63 on bottom chunk

            const t_data = std.testing.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
            defer std.testing.allocator.free(t_data);
            @memcpy(t_data, t_base_data);

            {
                const b_wp = chunk.worldPosition.initFromPositionV(.{ 0, 0, 0, 0 });
                // Set a dark and full non air block bottom chunk for fetcher
                const b_data = std.testing.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
                @memcpy(b_data, b_base_data);
                l.fetcher.test_chunk_data.put(b_wp, b_data) catch @panic("OOM");
            }

            const pos: @Vector(4, f32) = .{
                plane_pos[0] + @as(f32, @floatFromInt(_x)),
                plane_pos[1],
                plane_pos[2] + @as(f32, @floatFromInt(_z)),
                plane_pos[3],
            };
            const b_ci = chunk.getIndexFromPositionV(pos);

            var bd: block.BlockData = block.BlockData.fromId(t_data[b_ci]);
            bd.block_id = block_id;
            t_data[b_ci] = bd.toId();

            l.datas[0] = .{
                .wp = l.wp,
                .data = t_data,
            };

            // Do the thing.
            l.set_added_block_lighting(&bd, b_ci);

            // Check the thing got done.
            const bl_data = l.datas[1].data orelse @panic("expected data to be there");
            const tc: [5][5]?block.BlockLighingLevel = expected_lighting[test_case];
            var __x: usize = 0;
            outer: {
                while (__x < plane_dim) : (__x += 1) {
                    var __z: usize = 0;
                    while (__z < plane_dim) : (__z += 1) {
                        var failed_top = true;
                        var failed_top_surface = false;
                        const ll: block.BlockLighingLevel = tc[__x][__z] orelse break :outer;
                        const x: f32 = @floatFromInt(__x);
                        const z: f32 = @floatFromInt(__z);
                        const poss: @Vector(4, f32) = .{
                            plane_pos[0] + x,
                            plane_pos[1],
                            plane_pos[2] + z,
                            0,
                        };
                        const b_ciss = chunk.getIndexFromPositionV(poss);
                        errdefer std.debug.print(
                            "\n\nFAILED test_case: {d} \n- ci: {d} \n- failed at {d} {d} \n- ({d}, {d}, {d}) \n- failed top: {} \n- failed top surface: {}\n\n",
                            .{
                                test_case,
                                b_ciss,
                                __x,
                                __z,
                                plane_pos[0] + x,
                                plane_pos[1],
                                plane_pos[2] + z,
                                failed_top,
                                failed_top_surface,
                            },
                        );
                        // Test top
                        try testing_utils.utest_expect_surface_light_at_v(
                            t_data,
                            .{
                                plane_pos[0] + x,
                                plane_pos[1],
                                plane_pos[2] + z,
                                plane_pos[3],
                            },
                            .bottom,
                            ll,
                        );
                        failed_top = false;
                        failed_top_surface = true;
                        // top's top surface should always be full
                        try testing_utils.utest_expect_surface_light_at_v(
                            t_data,
                            .{
                                plane_pos[0] + x,
                                plane_pos[1],
                                plane_pos[2] + z,
                                plane_pos[3],
                            },
                            .top,
                            .full,
                        );
                        failed_top_surface = false;
                        // Test bottom
                        try testing_utils.utest_expect_surface_light_at_v(
                            bl_data,
                            .{
                                plane_pos[0] + x,
                                63,
                                plane_pos[2] + z,
                                plane_pos[3],
                            },
                            .top,
                            ll,
                        );
                    }
                }
            }

            @memcpy(t_base_data, t_data);
            @memcpy(b_base_data, bl_data);
            test_case += 1;
        }
    }
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
const data_fetcher = if (@import("builtin").is_test)
    (@import("test_data_fetcher.zig"))
else
    @import("data_fetcher.zig");
const testing_utils = @import("testing_utils.zig");
