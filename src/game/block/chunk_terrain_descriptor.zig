const default_frequency: f32 = -0.002;
const default_jitter: f32 = 2.31;
const default_octaves: i32 = 10;

pub const TerrainGenError = error{
    NoBlockTypeFound,
    NoConditionalSet,
    NoiseConditionalMisconfigured,
};

pub const noiseConfig = struct {
    frequency: f32 = default_frequency,
    noise_type: noiseType = .opensimplex2,

    fractal_type: fractalType = .none,
    octaves: i32 = default_octaves,
    lacunarity: f32 = 2.0,
    gain: f32 = 0.5,
    weighted_strength: f32 = 0.0,
    ping_pong_strength: f32 = 2.0,

    cellularDistanceFunc: cellularDistanceFunc = .euclideansq,
    cellularReturnType: cellularReturnType = .cellvalue,
    jitter: f32 = default_jitter,
};

// These are duplicated from znoise to avoid linking znoise for tests
pub const noiseType = enum(u8) {
    opensimplex2,
    opensimplex2s,
    cellular,
    perlin,
    value_cubic,
    value,
};

pub const fractalType = enum(u8) {
    none,
    fbm,
    ridged,
    pingpong,
    domain_warp_progressive,
    domain_warp_independent,
};

pub const cellularDistanceFunc = enum(u8) {
    euclidean,
    euclideansq,
    manhattan,
    hybrid,
};

pub const cellularReturnType = enum(u8) {
    cellvalue,
    distance,
    distance2,
    distance2add,
    distance2sub,
    distance2mul,
    distance2div,
};

pub const blockType = enum(u8) {
    air,
    stone,
    grass,
    dirt,
    lava,
    water,
};

pub const blockId = struct {
    block_type: blockType,
    block_id: u8,

    pub fn debugPrint(self: blockId, depth: usize) void {
        var i: usize = 0;
        while (i < depth) : (i += 1) std.debug.print("  ", .{});
        std.debug.print(" - blockId with id: {} and type: {}\n", .{ self.block_id, self.block_type });
    }
};

// blockColumn - a block column will allow multiple blocks, up to ten,
// to be specified for a noise generator script
// the block ids will chosed based on the percentage_interval given a
// normalized noise level from 0 to 1, if an percentage_interval is 25
// and there are 4 blocks they the first block will appear be
// chosen for noise values from 0 to 0.25 in descending order
// if not enough blocks are given to satisfy the interval
// the last block will be used for remaining values
//
// If interval is 0 it is assumed to be a single block.
pub const blockColumn = struct {
    has_blocks: bool = false,
    block_ids: [10]blockId = undefined,
    num_blocks: usize = 0,
    percentage_interval: usize = 0,

    pub fn addBlock(self: *blockColumn, bi: blockId) void {
        std.debug.assert(self.num_blocks + 1 != self.block_ids.len);
        self.block_ids[self.num_blocks] = bi;
        self.num_blocks += 1;
        self.has_blocks = true;
    }

    pub fn debugPrint(self: blockColumn, depth: usize) void {
        if (!self.has_blocks) return;
        var i: usize = 0;
        while (i < self.num_blocks) : (i += 1) self.block_ids[i].debugPrint(depth);
    }

    // Assumes normalized noise range from 0 to 1.
    pub fn getBlock(self: blockColumn, noise: f32) ?blockId {
        if (!self.has_blocks) return null;

        if (self.percentage_interval == 0) return self.block_ids[0];

        std.debug.assert(self.percentage_interval <= 100);
        std.debug.assert(noise >= 0 and noise <= 1);

        const n: usize = @intFromFloat(@floor(noise * 100.0));
        const i: usize = @divFloor(n, self.percentage_interval);
        if (i >= self.num_blocks) return self.block_ids[self.num_blocks - 1];
        return self.block_ids[i];
    }
};

pub const comparisonOperator = enum(u8) {
    eq,
    gt,
    lt,
    gte,
    lte,
};

pub const yPositionConditional = struct {
    y: usize = 0,
    operator: comparisonOperator = .eq,
    is_true: ?*descriptorNode = null,
    is_false: ?*descriptorNode = null,

    pub fn debugPrint(self: yPositionConditional, depth: usize) void {
        {
            var i: usize = 0;
            while (i < depth) : (i += 1) std.debug.print("  ", .{});
        }
        std.debug.print(" - yPositionConditional with y: {d} and operator: {}\n", .{ self.y, self.operator });
        if (self.is_true) |it| {
            {
                var i: usize = 0;
                while (i < depth) : (i += 1) std.debug.print("   is true:\n", .{});
            }
            it.debugPrint(depth + 1);
        }
        if (self.is_false) |it| {
            {
                var i: usize = 0;
                while (i < depth) : (i += 1) std.debug.print("   is false:\n", .{});
            }
            it.debugPrint(depth + 1);
        }
    }
};

pub const noiseConditional = struct {
    operator: comparisonOperator = .gt,
    absolute: bool = false,
    noise: ?f32 = 0, // hard coded noise value
    divisor: ?f32 = null, // divided from y
    is_true: ?*descriptorNode = null,
    is_false: ?*descriptorNode = null,

    pub fn debugPrint(self: noiseConditional, depth: usize) void {
        {
            var i: usize = 0;
            while (i < depth) : (i += 1) std.debug.print("  ", .{});
        }
        std.debug.print(" - noiseConditional with operator: {} and absolute: {}", .{ self.operator, self.absolute });
        if (self.noise) |n| {
            std.debug.print(" and noise: {}", .{n});
        }
        if (self.divisor) |d| {
            std.debug.print(" and divisor: {}", .{d});
        }
        std.debug.print("\n", .{});
        if (self.is_true) |it| {
            {
                var i: usize = 0;
                while (i < depth) : (i += 1) std.debug.print("   is true:\n", .{});
            }
            it.debugPrint(depth + 1);
        }
        if (self.is_false) |it| {
            {
                var i: usize = 0;
                while (i < depth) : (i += 1) std.debug.print("   is false:\n", .{});
            }
            it.debugPrint(depth + 1);
        }
    }
};

pub const descriptorNode = struct {
    blocks: blockColumn = .{},
    y_conditional: ?yPositionConditional = null,
    noise_conditional: ?noiseConditional = null,

    pub fn deinit(self: *descriptorNode, allocator: std.mem.Allocator) void {
        if (self.y_conditional) |yc| {
            if (yc.is_true) |d| d.deinit(allocator);
            if (yc.is_false) |d| d.deinit(allocator);
        }
        if (self.noise_conditional) |nc| {
            if (nc.is_true) |d| d.deinit(allocator);
            if (nc.is_false) |d| d.deinit(allocator);
        }
        allocator.destroy(self);
    }

    pub fn debugPrint(self: descriptorNode, depth: usize) void {
        var i: usize = 0;
        while (i < depth) : (i += 1) std.debug.print("  ", .{});
        std.debug.print(" - descriptorNode\n", .{});
        self.blocks.debugPrint(depth + 1);
        if (self.y_conditional) |yc| {
            yc.debugPrint(depth + 1);
        }
        if (self.noise_conditional) |nc| {
            nc.debugPrint(depth + 1);
        }
    }

    pub fn getBlockId(self: descriptorNode, y: usize, noise: f32) !blockId {
        return try self._getBlockId(self.blocks.getBlock(noise), y, noise) orelse TerrainGenError.NoBlockTypeFound;
    }

    fn _getBlockId(self: descriptorNode, current_block: ?blockId, y: usize, noise: f32) !?blockId {
        const cb = self.blocks.getBlock(noise) orelse current_block;
        if (self.y_conditional) |yc| {
            if (yc.is_false == null and yc.is_true == null) return TerrainGenError.NoConditionalSet;
            switch (yc.operator) {
                .eq => {
                    if (y == yc.y and yc.is_true != null) return yc.is_true.?._getBlockId(cb, y, noise);
                    if (yc.is_false) |d| return d._getBlockId(cb, y, noise);
                },
                .gt => {
                    if (y > yc.y and yc.is_true != null) return yc.is_true.?._getBlockId(cb, y, noise);
                    if (yc.is_false) |d| return d._getBlockId(cb, y, noise);
                },
                .lt => {
                    if (y < yc.y and yc.is_true != null) return yc.is_true.?._getBlockId(cb, y, noise);
                    if (yc.is_false) |d| return d._getBlockId(cb, y, noise);
                },
                .gte => {
                    if (y >= yc.y and yc.is_true != null) return yc.is_true.?._getBlockId(cb, y, noise);
                    if (yc.is_false) |d| return d._getBlockId(cb, y, noise);
                },
                .lte => {
                    if (y <= yc.y and yc.is_true != null) return yc.is_true.?._getBlockId(cb, y, noise);
                    if (yc.is_false) |d| return d._getBlockId(cb, y, noise);
                },
            }
        }
        if (self.noise_conditional) |nc| {
            if (nc.is_false == null and nc.is_true == null) return TerrainGenError.NoConditionalSet;
            if (nc.divisor == null and nc.noise == null) return TerrainGenError.NoiseConditionalMisconfigured;
            const nv = if (nc.absolute) @abs(noise) else noise;
            const ov = if (nc.divisor) |d| @as(f32, @floatFromInt(y)) / d else nc.noise.?;
            switch (nc.operator) {
                .eq => {
                    if (ov == nv and nc.is_true != null) return nc.is_true.?._getBlockId(cb, y, noise);
                    if (nc.is_false) |d| return d._getBlockId(cb, y, noise);
                },
                .gt => {
                    if (ov > nv and nc.is_true != null) return nc.is_true.?._getBlockId(cb, y, noise);
                    if (nc.is_false) |d| return d._getBlockId(cb, y, noise);
                },
                .lt => {
                    if (ov < nv and nc.is_true != null) return nc.is_true.?._getBlockId(cb, y, noise);
                    if (nc.is_false) |d| return d._getBlockId(cb, y, noise);
                },
                .gte => {
                    if (ov >= nv and nc.is_true != null) return nc.is_true.?._getBlockId(cb, y, noise);
                    if (nc.is_false) |d| return d._getBlockId(cb, y, noise);
                },
                .lte => {
                    if (ov <= nv and nc.is_true != null) return nc.is_true.?._getBlockId(cb, y, noise);
                    if (nc.is_false) |d| return d._getBlockId(cb, y, noise);
                },
            }
        }
        return cb;
    }
};

pub const root = struct {
    config: noiseConfig = .{},
    block_ids: [256]blockId = undefined,
    num_blocks: usize = 0,
    node: *descriptorNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) *root {
        const r = allocator.create(root) catch @panic("OOM");
        errdefer allocator.destroy(r);
        const d = allocator.create(descriptorNode) catch @panic("OOM");
        errdefer allocator.destroy(d);
        d.* = .{};
        r.* = .{
            .allocator = allocator,
            .node = d,
        };
        return r;
    }

    pub fn debugPrint(self: *root) void {
        std.debug.print("\n\n*** DEBUG PRINT DESCRIPTOR BEG ***\n", .{});
        std.debug.print("config: {}\n", .{self.config});
        self.node.debugPrint(0);
        std.debug.print("\n*** DEBUG PRINT DESCRIPTOR END ***\n\n", .{});
    }

    pub fn deinit(self: *root) void {
        self.node.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn registerBlock(self: *root, bi: blockId) void {
        self.block_ids[self.num_blocks] = bi;
        self.num_blocks += 1;
    }

    pub fn createNode(self: *root) *descriptorNode {
        const d = self.allocator.create(descriptorNode) catch @panic("OOM");
        d.* = .{};
        return d;
    }
};

test "basic test" {
    const b1: blockId = .{ .block_id = 0, .block_type = .air };
    const b2: blockId = .{ .block_id = 1, .block_type = .stone };
    const b3: blockId = .{ .block_id = 2, .block_type = .grass };

    var rn: *root = root.init(std.testing.allocator);
    defer rn.deinit();

    rn.registerBlock(b1);
    rn.registerBlock(b2);
    rn.registerBlock(b3);

    rn.node.blocks.addBlock(b2);
    rn.node.y_conditional = .{
        .y = 64,
        .operator = .gte,
    };

    var air_block = rn.createNode();
    air_block.blocks.addBlock(b1);
    rn.node.y_conditional.?.is_true = air_block;

    var bottom_chunk = rn.createNode();
    bottom_chunk.y_conditional = .{
        .y = 63,
        .operator = .eq,
    };

    var some_grass_on_top = rn.createNode();
    var grass_noise_conditional: noiseConditional = .{
        .noise = 0.5,
        .operator = .lte,
    };
    var grass_block = rn.createNode();
    grass_block.blocks.addBlock(b3);
    grass_noise_conditional.is_true = grass_block;
    some_grass_on_top.noise_conditional = grass_noise_conditional;

    bottom_chunk.y_conditional.?.is_true = some_grass_on_top;
    rn.node.y_conditional.?.is_false = bottom_chunk;

    // top chunk should all be air
    const test1 = rn.node.getBlockId(65, 1) catch @panic("expected block");
    try std.testing.expectEqual(b1.block_type, test1.block_type);
    try std.testing.expectEqual(b1.block_id, test1.block_id);

    // test y equal and noise matches
    const test2 = rn.node.getBlockId(63, 1) catch @panic("expected block");
    try std.testing.expectEqual(b3.block_type, test2.block_type);
    try std.testing.expectEqual(b3.block_id, test2.block_id);

    // Test y doesn't equal
    const test3 = rn.node.getBlockId(22, 1) catch @panic("expected block");
    try std.testing.expectEqual(b2.block_type, test3.block_type);
    try std.testing.expectEqual(b2.block_id, test3.block_id);

    // Test noise doesn't match
    const test4 = rn.node.getBlockId(63, 0.3) catch @panic("expected block");
    try std.testing.expectEqual(b2.block_type, test4.block_type);
    try std.testing.expectEqual(b2.block_id, test4.block_id);
}

test "basic test divisor" {
    const b1: blockId = .{ .block_id = 0, .block_type = .air };
    const b2: blockId = .{ .block_id = 1, .block_type = .stone };
    const b3: blockId = .{ .block_id = 2, .block_type = .grass };

    var rn: *root = root.init(std.testing.allocator);
    defer rn.deinit();

    rn.registerBlock(b1);
    rn.registerBlock(b2);
    rn.registerBlock(b3);

    rn.node.blocks.addBlock(b1);
    rn.node.y_conditional = .{
        .y = 64,
        .operator = .gte,
    };

    var stone_block = rn.createNode();
    stone_block.blocks.addBlock(b2);
    rn.node.y_conditional.?.is_false = stone_block;

    var some_hill_on_top = rn.createNode();
    var hill_conditional: noiseConditional = .{
        .divisor = 128,
        .operator = .lt,
    };
    var grass_block = rn.createNode();
    grass_block.blocks.addBlock(b3);
    hill_conditional.is_true = grass_block;

    rn.node.y_conditional.?.is_true = some_hill_on_top;
    some_hill_on_top.noise_conditional = hill_conditional;

    // bot chunk should all be stone
    const test1 = rn.node.getBlockId(33, 1) catch @panic("expected block");
    try std.testing.expectEqual(b2.block_type, test1.block_type);
    try std.testing.expectEqual(b2.block_id, test1.block_id);

    // test grass near the bottom of top chunk
    const test2 = rn.node.getBlockId(65, 1) catch @panic("expected block");
    try std.testing.expectEqual(b3.block_type, test2.block_type);
    try std.testing.expectEqual(b3.block_id, test2.block_id);

    // // test grass
    const test3 = rn.node.getBlockId(70, 1) catch @panic("expected block");
    try std.testing.expectEqual(b3.block_type, test3.block_type);
    try std.testing.expectEqual(b3.block_id, test3.block_id);

    // // Test noise doesn't match a bit higher
    const test4 = rn.node.getBlockId(100, 0.5) catch @panic("expected block");
    try std.testing.expectEqual(b1.block_type, test4.block_type);
    try std.testing.expectEqual(b1.block_id, test4.block_id);

    // // Test noise doesn't match all the way up
    const test5 = rn.node.getBlockId(127, 0.3) catch @panic("expected block");
    try std.testing.expectEqual(b1.block_type, test5.block_type);
    try std.testing.expectEqual(b1.block_id, test5.block_id);
}

test "block column noise interval" {
    const b1: blockId = .{ .block_id = 0, .block_type = .air };
    const b2: blockId = .{ .block_id = 1, .block_type = .grass };
    const b3: blockId = .{ .block_id = 2, .block_type = .dirt };
    const b4: blockId = .{ .block_id = 3, .block_type = .stone };

    var rn: *root = root.init(std.testing.allocator);
    defer rn.deinit();

    rn.registerBlock(b1);
    rn.registerBlock(b2);
    rn.registerBlock(b3);
    rn.registerBlock(b4);

    rn.node.blocks.percentage_interval = 10;
    rn.node.blocks.addBlock(b1);
    rn.node.blocks.addBlock(b2);
    rn.node.blocks.addBlock(b3);
    rn.node.blocks.addBlock(b4);

    // for no noise, return the first block
    const no_noise_test = rn.node.getBlockId(33, 0) catch @panic("expected block");
    try std.testing.expectEqual(b1.block_type, no_noise_test.block_type);
    try std.testing.expectEqual(b1.block_id, no_noise_test.block_id);

    // for minimal noise, return grass
    const surface_noise = rn.node.getBlockId(33, 0.1) catch @panic("expected block");
    try std.testing.expectEqual(b2.block_type, surface_noise.block_type);
    try std.testing.expectEqual(b2.block_id, surface_noise.block_id);

    // for more noise, return dirt
    const dirt_noise = rn.node.getBlockId(33, 0.2) catch @panic("expected block");
    try std.testing.expectEqual(b3.block_type, dirt_noise.block_type);
    try std.testing.expectEqual(b3.block_id, dirt_noise.block_id);

    // for even more noise, return stone
    const stone_noise = rn.node.getBlockId(33, 0.3) catch @panic("expected block");
    try std.testing.expectEqual(b4.block_type, stone_noise.block_type);
    try std.testing.expectEqual(b4.block_id, stone_noise.block_id);

    // then stone all the way down
    const last_noise = rn.node.getBlockId(33, 1) catch @panic("expected block");
    try std.testing.expectEqual(b4.block_type, last_noise.block_type);
    try std.testing.expectEqual(b4.block_id, last_noise.block_id);
}

const std = @import("std");
