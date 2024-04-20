const air: u8 = 0;

traverser: *chunk_traverser,

pub const Lighting = @This();

pub fn set_removed_block_lighting(self: *Lighting) void {
    self.darken_area_around_block();
    self.light_fall_around_block();
    self.determine_air_ambience_around_block();
    self.determine_air_ambience_around_block();
    self.determine_block_ambience_around_block();
    self.determine_block_surface_from_air();
}

pub fn set_added_block_lighting(self: *Lighting) void {
    self.darken_area_around_block();
    self.light_fall_around_block();
    self.determine_air_ambience_around_block();
    self.determine_air_ambience_around_block();
    self.determine_block_ambience_around_block();
    self.determine_block_surface_from_air();
}

pub fn darken_area_around_block(self: *Lighting) void {
    self.traverser.reset();
    // go 2 positions up and 2 positions out in every direction and nuke the light
    // in a 5x5x5 cube starting at the top going down and everything beneath the cube until
    // a surface is hit
    // then starting at the top, figure out what the ambient lighting should be for each
    // going down

    // go up 2
    const y: f32 = self.traverser.position[1] + 2;
    self.traverser.yMoveTo(y);
    // go out x znd z by 2 or as far as we can
    const x = self.traverser.position[0] - 2;
    self.traverser.xMoveTo(x);
    const z = self.traverser.position[2] - 2;
    self.traverser.zMoveTo(z);
    // set ends in the x and z direction
    const y_end = y - 5;
    const x_end = x + 5;
    const z_end = z + 5;
    // shut out the lights
    while (self.traverser.position[1] >= y_end) : (self.traverser.yNeg()) {
        while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
            while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
                self.traverser.current_bd.ambient = 0;
                self.traverser.saveBD();
            }
            self.traverser.zMoveTo(z);
        }
        self.traverser.xMoveTo(x);
    }
    // now darken each x, z from y_end until a surface is hit:
    self.traverser.yMoveTo(y_end);
    self.traverser.xMoveTo(x);
    self.traverser.zMoveTo(z);

    while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
        while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
            while (true) {
                if (self.traverser.current_bd.block_id != air) {
                    self.traverser.current_bd.setAmbient(.top, .none);
                    self.traverser.saveBD();
                    break;
                }
                self.traverser.current_bd.ambient = 0;
                self.traverser.saveBD();
                self.traverser.yNeg();
            }
            self.traverser.yMoveTo(y_end);
        }
        self.traverser.zMoveTo(z);
    }
}

pub fn light_fall_around_block(self: *Lighting) void {
    self.traverser.reset();

    const y: f32 = self.traverser.position[1] + 2;
    self.traverser.yMoveTo(y);
    const x = self.traverser.position[0] - 2;
    self.traverser.xMoveTo(x);
    const z = self.traverser.position[2] - 2;
    self.traverser.zMoveTo(z);
    const x_end = x + 5;
    const z_end = z + 5;

    while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
        while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
            var ll: block.BlockLighingLevel = .full;
            self.traverser.yPos();
            if (self.traverser.current_bd.block_id != air) {
                // No light falling here.
                self.traverser.yMoveTo(y);
                continue;
            } else {
                ll = self.traverser.current_bd.getFullAmbiance();
            }
            self.traverser.yMoveTo(y);
            while (true) {
                if (self.traverser.current_bd.block_id != air) {
                    // All done dropping light.
                    self.traverser.current_bd.setAmbient(.top, ll);
                    self.traverser.saveBD();
                    break;
                }
                self.traverser.current_bd.setFullAmbiance(ll);
                self.traverser.saveBD();
                self.traverser.yNeg();
            }
            self.traverser.yMoveTo(y);
        }
        self.traverser.zMoveTo(z);
    }
}

pub fn determine_air_ambience_around_block(self: *Lighting) void {
    self.traverser.reset();

    // find the adjacent air ambiance for non fully ambiant are and propagate it
    const y: f32 = self.traverser.position[1] + 2;
    self.traverser.yMoveTo(y);
    const x = self.traverser.position[0] - 2;
    self.traverser.xMoveTo(x);
    const z = self.traverser.position[2] - 2;
    self.traverser.zMoveTo(z);
    const y_end = y - 5;
    const x_end = x + 5;
    const z_end = z + 5;

    while (self.traverser.position[1] >= y_end) : (self.traverser.yNeg()) {
        while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
            while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
                if (self.traverser.current_bd.block_id != air) continue;
                if (self.traverser.current_bd.getFullAmbiance() != .none) continue; // already has ambiance
                const ll = self.get_ambience_from_adjecent();
                self.traverser.current_bd.setFullAmbiance(ll);
                self.traverser.saveBD();
            }
            self.traverser.zMoveTo(z);
        }
        self.traverser.xMoveTo(x);
    }

    self.traverser.yMoveTo(y_end);
    self.traverser.xMoveTo(x);
    self.traverser.zMoveTo(z);

    while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
        while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
            while (true) {
                if (self.traverser.current_bd.block_id != air) break;
                const ll = self.get_ambience_from_adjecent();
                self.traverser.current_bd.setFullAmbiance(ll);
                self.traverser.saveBD();
                self.traverser.yNeg();
            }
            self.traverser.yMoveTo(y_end);
        }
        self.traverser.zMoveTo(z);
    }
}

pub fn determine_block_ambience_around_block(self: *Lighting) void {
    self.traverser.reset();

    const y: f32 = self.traverser.position[1] + 2;
    self.traverser.yMoveTo(y);
    const x = self.traverser.position[0] - 2;
    self.traverser.xMoveTo(x);
    const z = self.traverser.position[2] - 2;
    self.traverser.zMoveTo(z);
    const y_end = y - 5;
    const x_end = x + 5;
    const z_end = z + 5;

    while (self.traverser.position[1] >= y_end) : (self.traverser.yNeg()) {
        while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
            while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
                if (self.traverser.current_bd.block_id == air) continue;
                self.set_surfaces_directly_from_ambient();
            }
            self.traverser.zMoveTo(z);
        }
        self.traverser.xMoveTo(x);
    }

    self.traverser.yMoveTo(y_end);
    self.traverser.xMoveTo(x);
    self.traverser.zMoveTo(z);

    while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
        while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
            while (true) {
                if (self.traverser.current_bd.block_id != air) {
                    self.set_surfaces_directly_from_ambient();
                    break;
                }
                if (self.traverser.world_location[1] == 0) break;
                self.traverser.yNeg();
            }
            self.traverser.yMoveTo(y_end);
        }
        self.traverser.zMoveTo(z);
    }
}

pub fn determine_block_surface_from_air(self: *Lighting) void {
    self.traverser.reset();

    const y: f32 = self.traverser.position[1] + 2;
    self.traverser.yMoveTo(y);
    const x = self.traverser.position[0] - 2;
    self.traverser.xMoveTo(x);
    const z = self.traverser.position[2] - 2;
    self.traverser.zMoveTo(z);
    const y_end = y - 5;
    const x_end = x + 5;
    const z_end = z + 5;

    while (self.traverser.position[1] >= y_end) : (self.traverser.yNeg()) {
        while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
            while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
                if (self.traverser.current_bd.block_id != air) continue;
                self.set_surfaces_from_ambient_air();
            }
            self.traverser.zMoveTo(z);
        }
        self.traverser.xMoveTo(x);
    }

    self.traverser.yMoveTo(y_end);
    self.traverser.xMoveTo(x);
    self.traverser.zMoveTo(z);

    while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
        while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
            while (true) {
                if (self.traverser.current_bd.block_id != air) {
                    break;
                }
                self.set_surfaces_from_ambient_air();
                if (self.traverser.world_location[1] == 0) break;
                self.traverser.yNeg();
            }
            self.traverser.yMoveTo(y_end);
        }
        self.traverser.zMoveTo(z);
    }
}

pub fn set_surfaces_from_ambient_air(self: *Lighting) void {
    const cached_pos = self.traverser.position;
    // if (cached_pos[0] == 59) {
    //     std.debug.print("bi: {d} - pos {d} {d} {d} {d} - ll: {}\n", .{
    //         self.traverser.current_bd.block_id,
    //         cached_pos[0],
    //         cached_pos[1],
    //         cached_pos[2],
    //         cached_pos[3],
    //         self.traverser.current_bd.getFullAmbiance(),
    //     });
    // }
    if (self.traverser.current_bd.block_id != air) return;
    const ll = self.traverser.current_bd.getFullAmbiance();
    xPos: {
        self.traverser.xPos();
        if (self.traverser.current_bd.block_id == air) break :xPos;
        self.traverser.current_bd.setAmbient(.left, ll);
        self.traverser.saveBD();
    }
    self.traverser.xMoveTo(cached_pos[0]);
    xNeg: {
        self.traverser.xNeg();
        if (self.traverser.current_bd.block_id == air) break :xNeg;
        self.traverser.current_bd.setAmbient(.right, ll);
        self.traverser.saveBD();
    }
    self.traverser.xMoveTo(cached_pos[0]);
    yPos: {
        self.traverser.yPos();
        if (self.traverser.current_bd.block_id == air) break :yPos;
        self.traverser.current_bd.setAmbient(.bottom, ll);
        self.traverser.saveBD();
    }
    self.traverser.yMoveTo(cached_pos[1]);
    yNeg: {
        self.traverser.yNeg();
        if (self.traverser.current_bd.block_id == air) break :yNeg;
        self.traverser.current_bd.setAmbient(.top, ll);
        self.traverser.saveBD();
    }
    self.traverser.yMoveTo(cached_pos[1]);
    zPos: {
        self.traverser.zPos();
        if (self.traverser.current_bd.block_id == air) break :zPos;
        // self.traverser.current_bd.setAmbient(.top, ll);
        // self.traverser.current_bd.setAmbient(.bottom, ll);
        // self.traverser.current_bd.setAmbient(.front, .full);
        // self.traverser.current_bd.setAmbient(.back, .full);
        self.traverser.current_bd.setAmbient(.front, ll);
        // if (@reduce(.And, self.traverser.chunk_position == @Vector(4, f32){ 59, 2, 0, 0 })) {
        //     std.debug.print("\n\n\nYO: bi: {d} - pos {d} {d} {d} {d} - sf_ll: {} - ll: {} ambiant: {x} {x}\n\n\n", .{
        //         self.traverser.current_bd.block_id,
        //         self.traverser.chunk_position[0],
        //         self.traverser.chunk_position[1],
        //         self.traverser.chunk_position[2],
        //         self.traverser.chunk_position[3],
        //         self.traverser.current_bd.getSurfaceAmbience(.front),
        //         ll,
        //         (self.traverser.current_bd.ambient & 0x0F0) >> 6,
        //         (self.traverser.current_bd.ambient ^ (0xFFF - 0x0C0)) >> 6,
        //     });
        // }
        self.traverser.saveBD();
    }
    self.traverser.zMoveTo(cached_pos[2]);
    zNeg: {
        self.traverser.zNeg();
        if (self.traverser.current_bd.block_id == air) break :zNeg;
        self.traverser.current_bd.setAmbient(.back, ll);
        self.traverser.saveBD();
    }
    self.traverser.zMoveTo(cached_pos[2]);
}

pub fn set_surfaces_directly_from_ambient(self: *Lighting) void {
    const cached_pos = self.traverser.position;
    var bd = self.traverser.current_bd;
    bd.setFullAmbiance(.none);
    {
        self.traverser.xPos();
        if (self.traverser.current_bd.block_id != air) bd.setAmbient(.right, .none);
        const c_ll = self.traverser.current_bd.getFullAmbiance();
        bd.setAmbient(.right, c_ll);
    }
    self.traverser.xMoveTo(cached_pos[0]);
    {
        self.traverser.xNeg();
        if (self.traverser.current_bd.block_id != air) bd.setAmbient(.left, .none);
        const c_ll = self.traverser.current_bd.getFullAmbiance();
        bd.setAmbient(.left, c_ll);
    }
    self.traverser.xMoveTo(cached_pos[0]);
    {
        self.traverser.yPos();
        if (self.traverser.current_bd.block_id != air) bd.setAmbient(.top, .none);
        const c_ll = self.traverser.current_bd.getFullAmbiance();
        bd.setAmbient(.top, c_ll);
    }
    self.traverser.yMoveTo(cached_pos[1]);
    {
        self.traverser.yNeg();
        if (self.traverser.current_bd.block_id != air) bd.setAmbient(.bottom, .none);
        const c_ll = self.traverser.current_bd.getFullAmbiance();
        bd.setAmbient(.bottom, c_ll);
    }
    self.traverser.yMoveTo(cached_pos[1]);
    {
        self.traverser.zPos();
        if (self.traverser.current_bd.block_id != air) bd.setAmbient(.back, .none);
        const c_ll = self.traverser.current_bd.getFullAmbiance();
        bd.setAmbient(.back, c_ll);
    }
    self.traverser.zMoveTo(cached_pos[2]);
    {
        self.traverser.zNeg();
        if (self.traverser.current_bd.block_id != air) bd.setAmbient(.front, .none);
        const c_ll = self.traverser.current_bd.getFullAmbiance();
        bd.setAmbient(.front, c_ll);
    }
    self.traverser.zMoveTo(cached_pos[2]);
    self.traverser.current_bd = bd;
    self.traverser.saveBD();
}

pub fn get_ambience_from_adjecent(self: *Lighting) block.BlockLighingLevel {
    const cached_pos = self.traverser.position;
    // now update adjacent
    var ll: block.BlockLighingLevel = .none;
    y_pos: {
        // If above is air we don't darken that brightness.
        self.traverser.yPos();
        if (self.traverser.current_bd.block_id != air) break :y_pos;
        const c_ll = self.traverser.current_bd.getFullAmbiance();
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    self.traverser.yMoveTo(cached_pos[1]);
    x_pos: {
        self.traverser.xPos();
        if (self.traverser.current_bd.block_id != air) break :x_pos;
        const c_ll = self.traverser.current_bd.getFullAmbiance().getNextDarker();
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    self.traverser.xMoveTo(cached_pos[0]);
    x_neg: {
        self.traverser.xNeg();
        if (self.traverser.current_bd.block_id != air) break :x_neg;
        const c_ll = self.traverser.current_bd.getFullAmbiance().getNextDarker();
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    self.traverser.xMoveTo(cached_pos[0]);
    z_pos: {
        self.traverser.zPos();
        if (self.traverser.current_bd.block_id != air) break :z_pos;
        const c_ll = self.traverser.current_bd.getFullAmbiance().getNextDarker();
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    self.traverser.zMoveTo(cached_pos[2]);
    z_neg: {
        self.traverser.zNeg();
        if (self.traverser.current_bd.block_id != air) break :z_neg;
        const c_ll = self.traverser.current_bd.getFullAmbiance().getNextDarker();
        if (c_ll.isBrighterThan(ll)) ll = c_ll;
    }
    self.traverser.zMoveTo(cached_pos[2]);
    return ll;
}

test "lighting basic remove block lighting fall" {
    const t_data = testing_utils.utest_allocate_test_chunk(0, .full);
    defer std.testing.allocator.free(t_data);

    // set a dark ground floor across y = 0
    testing_utils.utest_add_floor_at_y(t_data, 0, .none);
    const _x: f32 = 16;
    const _z: f32 = 16;
    const ci = chunk.getIndexFromPositionV(.{ _x, 1, _z, 0 });

    testing_utils.utest_set_block_surface_light(t_data, ci, .full, .bottom, .none);

    const t_wp = chunk.worldPosition.initFromPositionV(.{ 0, 1, 0, 0 });
    var test_traverser = chunk_traverser.init(std.testing.allocator, .{}, t_wp, ci, .{
        .wp = t_wp,
        .data = t_data,
    });
    test_traverser.fetcher.init();
    defer test_traverser.deinit();
    defer test_traverser.fetcher.deinit();

    const b_wp = chunk.worldPosition.initFromPositionV(.{ 0, 0, 0, 0 });
    {
        // Set a dark and full non air block bottom chunk for fetcher
        const b_data = testing_utils.utest_allocate_test_chunk(1, .none);
        // set a lit ground floor across y = 63 on bottom chunk
        test_traverser.fetcher.test_chunk_data.put(b_wp, b_data) catch @panic("OOM");
    }

    var l: Lighting = .{ .traverser = &test_traverser };
    // validate the block below placement is dark on the surface
    try testing_utils.utest_expect_surface_light_at_v(t_data, .{ _x, 0, _z, 0 }, .top, .none);

    var bd: block.BlockData = block.BlockData.fromId(t_data[ci]);
    bd.block_id = 0;
    t_data[ci] = bd.toId();
    l.set_removed_block_lighting();

    // validate that the block below's surface is now fully lit
    try testing_utils.utest_expect_surface_light_at_v(t_data, .{ _x, 0, _z, 0 }, .top, .full);
}

test "lighting adding block across chunks darkness fall" {
    const t_data = testing_utils.utest_allocate_test_chunk(0, .full);
    defer std.testing.allocator.free(t_data);

    const _x: f32 = 16;
    const _z: f32 = 16;
    const ci = chunk.getIndexFromPositionV(.{ _x, 5, _z, 0 });
    // Set a block on y, a bit above bottom chunk.
    {
        // Set a block above of the dark ground in y 1:
        var bd: block.BlockData = block.BlockData.fromId(1);
        t_data[ci] = bd.toId();
    }

    const t_wp = chunk.worldPosition.initFromPositionV(.{ 0, 1, 0, 0 });
    var test_traverser = chunk_traverser.init(std.testing.allocator, .{}, t_wp, ci, .{
        .wp = t_wp,
        .data = t_data,
    });
    test_traverser.fetcher.init();
    defer test_traverser.deinit();
    defer test_traverser.fetcher.deinit();

    const b_wp = chunk.worldPosition.initFromPositionV(.{ 0, 0, 0, 0 });
    {
        // Set a dark and full non air block bottom chunk for fetcher
        const b_data = testing_utils.utest_allocate_test_chunk(1, .none);
        // set a lit ground floor across y = 63 on bottom chunk
        testing_utils.utest_add_floor_at_y(b_data, 63, .full);
        test_traverser.fetcher.test_chunk_data.put(b_wp, b_data) catch @panic("OOM");
    }

    // validate the block on the chunk below where placement will occur is fully list on the surface
    {
        const b_data = test_traverser.fetcher.test_chunk_data.get(b_wp) orelse @panic("expected bottom wp");
        try testing_utils.utest_expect_surface_light_at_v(b_data, .{ _x, 63, _z, 0 }, .top, .full);
    }
    var l: Lighting = .{ .traverser = &test_traverser };

    l.set_added_block_lighting();
    // validate that the block on chunk below's surface is now fully lit
    {
        // expected lighting to have fetched extra data for bottom chunk
        try std.testing.expectEqual(1, test_traverser.num_extra_datas);
        // expected extra data to have been fetchable
        try std.testing.expect(test_traverser.datas[1].fetchable);
        const b_data = test_traverser.datas[1].data orelse @panic("expected data to be there");
        // bright is one level darker than full.
        try testing_utils.utest_expect_surface_light_at_v(b_data, .{ _x, 63, _z, 0 }, .top, .bright);
    }
}

test "lighting removing block across chunks lighting falls" {
    // set a lit ground floor across y = 63 on bottom chunk
    const t_data = testing_utils.utest_allocate_test_chunk(0, .full);
    defer std.testing.allocator.free(t_data);

    // Set a block on y, just a slight ways above bottom chunk.
    const _x: f32 = 16;
    const _z: f32 = 16;
    const ci = chunk.getIndexFromPositionV(.{ _x, 0, _z, 0 });
    // Set a block on top of the dark ground in y 1:
    testing_utils.utest_set_block_surface_light(t_data, ci, .full, .bottom, .none);

    const t_wp = chunk.worldPosition.initFromPositionV(.{ 0, 1, 0, 0 });
    var test_traverser = chunk_traverser.init(std.testing.allocator, .{}, t_wp, ci, .{
        .wp = t_wp,
        .data = t_data,
    });
    test_traverser.fetcher.init();
    defer test_traverser.deinit();
    defer test_traverser.fetcher.deinit();

    const b_wp = chunk.worldPosition.initFromPositionV(.{ 0, 0, 0, 0 });
    {
        // Set a dark and full non air block bottom chunk for fetcher
        const b_data = testing_utils.utest_allocate_test_chunk(1, .none);
        test_traverser.fetcher.test_chunk_data.put(b_wp, b_data) catch @panic("OOM");
    }
    var l: Lighting = .{ .traverser = &test_traverser };
    // validate the block on the chunk below placement is dark on the surface
    {
        const b_data = test_traverser.fetcher.test_chunk_data.get(b_wp) orelse @panic("expected bottom wp");
        try testing_utils.utest_expect_surface_light_at_v(b_data, .{ _x, 63, _z, 0 }, .top, .none);
    }
    var bd: block.BlockData = block.BlockData.fromId(t_data[ci]);
    bd.block_id = 0;
    t_data[ci] = bd.toId();
    l.set_removed_block_lighting();
    // validate that the block on chunk below's surface is now fully lit
    {
        // expected lighting to have fetched extra data for bottom chunk
        try std.testing.expectEqual(1, test_traverser.num_extra_datas);
        // expected extra data to have been fetchable
        try std.testing.expect(test_traverser.datas[1].fetchable);
        const b_data = test_traverser.datas[1].data orelse @panic("expected data to be there");
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
            .{ .bright, .dark,   .dark,   .bright, .bright },
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
            // set a lit ground floor across y = 63 on bottom chunk

            const t_data = std.testing.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
            defer std.testing.allocator.free(t_data);
            @memcpy(t_data, t_base_data);

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

            const t_wp = chunk.worldPosition.initFromPositionV(.{ 0, 1, 0, 0 });
            var test_traverser = chunk_traverser.init(std.testing.allocator, .{}, t_wp, b_ci, .{
                .wp = t_wp,
                .data = t_data,
            });
            test_traverser.fetcher.init();
            defer test_traverser.deinit();
            defer test_traverser.fetcher.deinit();

            {
                const b_wp = chunk.worldPosition.initFromPositionV(.{ 0, 0, 0, 0 });
                // Set a dark and full non air block bottom chunk for fetcher
                const b_data = std.testing.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
                @memcpy(b_data, b_base_data);
                test_traverser.fetcher.test_chunk_data.put(b_wp, b_data) catch @panic("OOM");
            }

            var l: Lighting = .{ .traverser = &test_traverser };
            // Do the thing.
            l.set_added_block_lighting();

            // Check the thing got done.
            const bl_data = test_traverser.datas[1].data orelse @panic("expected data to be there");
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

test "test block on chunk edge casts shadow on other chunks surfaces and chunk below" {
    const t_data = testing_utils.utest_allocate_test_chunk(0, .full);
    defer std.testing.allocator.free(t_data);

    const _x: f32 = 59;
    const _y: f32 = 4;
    const _z: f32 = 63; // putting a block right along the z edge
    const ci = chunk.getIndexFromPositionV(.{ _x, _y, _z, 0 });
    testing_utils.utest_set_block_surface_light(t_data, ci, .full, .bottom, .none);

    const t_wp = chunk.worldPosition.initFromPositionV(.{ 0, 1, 0, 0 });
    var test_traverser = chunk_traverser.init(std.testing.allocator, .{}, t_wp, ci, .{
        .wp = t_wp,
        .data = t_data,
    });
    test_traverser.fetcher.init();
    defer test_traverser.deinit();
    defer test_traverser.fetcher.deinit();

    const b_wp = chunk.worldPosition.initFromPositionV(.{ 0, 0, 0, 0 });
    {
        const b_data = testing_utils.utest_allocate_test_chunk(1, .full);
        testing_utils.utest_add_floor_at_y(b_data, 63, .full);
        test_traverser.fetcher.test_chunk_data.put(b_wp, b_data) catch @panic("OOM");
    }

    const zp_wp = chunk.worldPosition.initFromPositionV(.{ 0, 1, 1, 0 });
    {
        const zp_data = testing_utils.utest_allocate_test_chunk(0, .full);
        var surfaces: [6]?block.BlockSurface = undefined;
        surfaces[0] = .back;
        surfaces[1] = .front;
        testing_utils.utest_add_plane_at_x(
            zp_data,
            .{ 43, 0, 0, 0 },
            20,
            surfaces,
            2,
            .none,
        );
        test_traverser.fetcher.test_chunk_data.put(zp_wp, zp_data) catch @panic("OOM");
    }
    {
        // z+ bottom chunk is needed by the algorithm:
        const zpb_wp = chunk.worldPosition.initFromPositionV(.{ 0, 0, 1, 0 });
        const zpb_data = testing_utils.utest_allocate_test_chunk(1, .full);
        test_traverser.fetcher.test_chunk_data.put(zpb_wp, zpb_data) catch @panic("OOM");
    }
    var l: Lighting = .{ .traverser = &test_traverser };

    var bd: block.BlockData = block.BlockData.fromId(t_data[ci]);
    bd.block_id = 1;
    t_data[ci] = bd.toId();
    l.set_added_block_lighting();
    {
        // expected lighting to have fetched extra data for three chunks
        try std.testing.expectEqual(3, test_traverser.num_extra_datas);
        // expected extra data to have been fetchable
        try std.testing.expect(test_traverser.datas[1].fetchable);
        try std.testing.expect(test_traverser.datas[2].fetchable);
    }
    {
        // validate that the block casted a shadow on the chunk below
        var test_data: ?[]u32 = null;
        for (test_traverser.datas) |d| {
            if (d.wp.equal(b_wp)) test_data = d.data;
        }
        std.debug.assert(test_data != null);
        const b_data = test_data.?;
        try testing_utils.utest_expect_surface_light_at_v(b_data, .{ _x, 63, _z, 0 }, .top, .bright);
    }
    {
        // expect a shadow across the back surface of the z plus chunk
        var test_data: ?[]u32 = null;
        for (test_traverser.datas) |d| {
            if (d.wp.equal(zp_wp)) test_data = d.data;
        }
        std.debug.assert(test_data != null);
        const zp_data = test_data.?;
        const pos: @Vector(4, f32) = .{ 59, 2, 0, 0 };
        try testing_utils.utest_expect_surface_light_at_v(zp_data, pos, .back, .bright);
    }
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
const chunk_traverser = @import("chunk_traverser.zig");
const data_fetcher = if (@import("builtin").is_test)
    (@import("test_data_fetcher.zig"))
else
    @import("data_fetcher.zig");
const testing_utils = @import("testing_utils.zig");
