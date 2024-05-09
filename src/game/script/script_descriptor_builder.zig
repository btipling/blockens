root: *desc.root = undefined,
allocator: std.mem.Allocator = undefined,
map: std.ArrayListUnmanaged(*desc.descriptorNode),
lua: *Lua = undefined,

const Builder = @This();
var builder: *Builder = undefined;

// Only one of these can exist a time. Caller owns root.
pub fn init(allocator: std.mem.Allocator, lua: *Lua) *Builder {
    const b = allocator.create(
        Builder,
    ) catch @panic("OOM");
    errdefer allocator.destroy(b);
    const r = desc.root.init(allocator);
    errdefer r.deinit();

    b.* = .{
        .root = r,
        .allocator = allocator,
        .map = std.ArrayListUnmanaged(*desc.descriptorNode){},
        .lua = lua,
    };
    builder = b;
    builder.map.append(allocator, r.node) catch @panic("OOM");
    return b;
}

// root is not deinited intentionally
pub fn deinit(self: *Builder) void {
    self.map.deinit(self.allocator);
    self.allocator.destroy(self);
}

fn createDesc(lua: *Lua) i32 {
    const d = builder.root.createNode();

    const i = builder.map.items.len;
    builder.map.append(builder.allocator, d) catch @panic("OOM");
    lua.pushInteger(@intCast(i));
    return 1;
}

fn getRootNode(lua: *Lua) i32 {
    lua.pushInteger(0);
    return 1;
}

fn setRootNode(lua: *Lua) i32 {
    const desc_id: u8 = @intCast(lua.toInteger(1) catch 0);

    const d = builder.root.createNode();
    builder.map.items[desc_id].y_conditional.?.is_true = d;

    const i = builder.map.items.len;
    builder.map.append(builder.allocator, d) catch @panic("OOM");
    lua.pushInteger(@intCast(i));
    return 1;
}

fn addBlockId(lua: *Lua) i32 {
    const id: u8 = @intCast(lua.toInteger(1) catch 0);
    const block_type: u8 = @intCast(lua.toInteger(2) catch 0);
    builder.root.addBlock(.{ .block_id = id, .block_type = @enumFromInt(block_type) });
    return 1;
}

fn setDescBlock(lua: *Lua) i32 {
    const desc_id: u8 = @intCast(lua.toInteger(1) catch -1);
    const block_type_index: u8 = @intCast(lua.toInteger(2) catch -1);
    const block_type: desc.blockType = @enumFromInt(block_type_index);
    var d = builder.map.items[desc_id];
    for (builder.root.block_ids) |bi| {
        if (bi.block_type == block_type) {
            d.block_id = bi;
            return 1;
        }
    }
    std.log.err("Invalid block id given to desc", .{});
    return 1;
}

fn setYCondition(lua: *Lua) i32 {
    const desc_id: u8 = @intCast(lua.toInteger(1) catch 0);
    const operator: u8 = @intCast(lua.toInteger(2) catch 0);
    const y: u8 = @intCast(lua.toInteger(3) catch 0);
    var d = builder.map.items[desc_id];
    d.y_conditional = .{
        .y = y,
        .operator = @enumFromInt(operator),
    };
    return 1;
}

fn setYConditionTrue(lua: *Lua) i32 {
    const desc_id: u8 = @intCast(lua.toInteger(1) catch 0);

    const d = builder.root.createNode();
    builder.map.items[desc_id].y_conditional.?.is_true = d;

    const i = builder.map.items.len;
    builder.map.append(builder.allocator, d) catch @panic("OOM");
    lua.pushInteger(@intCast(i));
    return 1;
}

fn setYConditionFalse(lua: *Lua) i32 {
    const desc_id: u8 = @intCast(lua.toInteger(1) catch 0);

    const d = builder.root.createNode();
    builder.map.items[desc_id].y_conditional.?.is_false = d;

    const i = builder.map.items.len;
    builder.map.append(builder.allocator, d) catch @panic("OOM");
    lua.pushInteger(@intCast(i));
    return 1;
}

fn setNoiseConditionWithNoise(lua: *Lua) i32 {
    const desc_id: u8 = @intCast(lua.toInteger(1) catch 0);
    const operator: u8 = @intCast(lua.toInteger(2) catch 0);
    const noise: f32 = @floatCast(lua.toNumber(3) catch 0);
    var d = builder.map.items[desc_id];
    d.noise_conditional = .{
        .noise = noise,
        .operator = @enumFromInt(operator),
    };
    return 1;
}

fn setNoiseConditionWithDivisor(lua: *Lua) i32 {
    const desc_id: u8 = @intCast(lua.toInteger(1) catch 0);
    const operator: u8 = @intCast(lua.toInteger(2) catch 0);
    const divisor: f32 = @floatCast(lua.toNumber(3) catch 0);
    var d = builder.map.items[desc_id];
    d.noise_conditional = .{
        .divisor = divisor,
        .operator = @enumFromInt(operator),
    };
    return 1;
}

fn setNoiseConditionTrue(lua: *Lua) i32 {
    const desc_id: u8 = @intCast(lua.toInteger(1) catch 0);

    const d = builder.root.createNode();
    builder.map.items[desc_id].noise_conditional.?.is_true = d;

    const i = builder.map.items.len;
    builder.map.append(builder.allocator, d) catch @panic("OOM");
    lua.pushInteger(@intCast(i));
    return 1;
}

fn setNoiseConditionFalse(lua: *Lua) i32 {
    const desc_id: u8 = @intCast(lua.toInteger(1) catch 0);

    const d = builder.root.createNode();
    builder.map.items[desc_id].noise_conditional.?.is_false = d;

    const i = builder.map.items.len;
    builder.map.append(builder.allocator, d) catch @panic("OOM");
    lua.pushInteger(@intCast(i));
    return 1;
}

fn setFreq(lua: *Lua) i32 {
    builder.root.config.frequency = @floatCast(lua.toNumber(1) catch 0);
    return 1;
}

fn setJitter(lua: *Lua) i32 {
    builder.root.config.jitter = @floatCast(lua.toNumber(1) catch 0);
    return 1;
}

fn setOctaves(lua: *Lua) i32 {
    builder.root.config.octaves = @intCast(lua.toInteger(1) catch 0);
    return 1;
}

fn setLacunarity(lua: *Lua) i32 {
    builder.root.config.lacunarity = @floatCast(lua.toNumber(1) catch 0);
    return 1;
}

fn setGain(lua: *Lua) i32 {
    builder.root.config.gain = @floatCast(lua.toNumber(1) catch 0);
    return 1;
}

fn setWeightedStrength(lua: *Lua) i32 {
    builder.root.config.weighted_strength = @floatCast(lua.toNumber(1) catch 0);
    return 1;
}

fn setPingPongStrength(lua: *Lua) i32 {
    builder.root.config.ping_pong_strength = @floatCast(lua.toNumber(1) catch 0);
    return 1;
}

fn setNoiseType(lua: *Lua) i32 {
    const nt = lua.toInteger(1) catch 0;
    switch (nt) {
        0 => builder.root.config.noise_type = .opensimplex2,
        1 => builder.root.config.noise_type = .opensimplex2s,
        2 => builder.root.config.noise_type = .cellular,
        3 => builder.root.config.noise_type = .perlin,
        4 => builder.root.config.noise_type = .value_cubic,
        else => builder.root.config.noise_type = .value,
    }
    return 1;
}

fn setFractalType(lua: *Lua) i32 {
    const nt = lua.toInteger(1) catch 0;
    switch (nt) {
        0 => builder.root.config.fractal_type = .none,
        1 => builder.root.config.fractal_type = .fbm,
        2 => builder.root.config.fractal_type = .ridged,
        3 => builder.root.config.fractal_type = .pingpong,
        4 => builder.root.config.fractal_type = .domain_warp_progressive,
        else => builder.root.config.fractal_type = .domain_warp_independent,
    }
    return 1;
}

fn setCelluarDistanceFunc(lua: *Lua) i32 {
    const nt = lua.toInteger(1) catch 0;
    switch (nt) {
        0 => builder.root.config.cellularDistanceFunc = .euclidean,
        1 => builder.root.config.cellularDistanceFunc = .euclideansq,
        3 => builder.root.config.cellularDistanceFunc = .manhattan,
        else => builder.root.config.cellularDistanceFunc = .hybrid,
    }
    return 1;
}

fn setCelluarReturnType(lua: *Lua) i32 {
    const nt = lua.toInteger(1) catch 0;
    switch (nt) {
        0 => builder.root.config.cellularReturnType = .cellvalue,
        1 => builder.root.config.cellularReturnType = .distance,
        2 => builder.root.config.cellularReturnType = .distance2,
        3 => builder.root.config.cellularReturnType = .distance2add,
        4 => builder.root.config.cellularReturnType = .distance2sub,
        5 => builder.root.config.cellularReturnType = .distance2mul,
        else => builder.root.config.cellularReturnType = .distance2div,
    }
    return 1;
}

pub fn build_descriptor(self: *Builder) void {
    const li = self.lua;
    {
        li.pushFunction(ziglua.wrap(getRootNode));
        li.setGlobal("get_root_node");
        li.pushFunction(ziglua.wrap(createDesc));
        li.setGlobal("create_desc");
        li.pushFunction(ziglua.wrap(addBlockId));
        li.setGlobal("add_block_id");
        li.pushFunction(ziglua.wrap(setDescBlock));
        li.setGlobal("set_desc_block");
        li.pushFunction(ziglua.wrap(setYCondition));
        li.setGlobal("set_y_cond");
        li.pushFunction(ziglua.wrap(setYConditionTrue));
        li.setGlobal("set_y_cond_true");
        li.pushFunction(ziglua.wrap(setYConditionFalse));
        li.setGlobal("set_y_cond_false");
        li.pushFunction(ziglua.wrap(setNoiseConditionWithNoise));
        li.setGlobal("set_noise_cond_with_noise");
        li.pushFunction(ziglua.wrap(setNoiseConditionWithDivisor));
        li.setGlobal("set_noise_cond_with_div");
        li.pushFunction(ziglua.wrap(setNoiseConditionTrue));
        li.setGlobal("set_noise_cond_true");
        li.pushFunction(ziglua.wrap(setNoiseConditionFalse));
        li.setGlobal("set_noise_cond_false");

        li.pushFunction(ziglua.wrap(setFreq));
        li.setGlobal("set_frequency");
        li.pushFunction(ziglua.wrap(setJitter));
        li.setGlobal("set_jitter");
        li.pushFunction(ziglua.wrap(setOctaves));
        li.setGlobal("set_octaves");

        li.pushFunction(ziglua.wrap(setLacunarity));
        li.setGlobal("set_lacunarity");
        li.pushFunction(ziglua.wrap(setGain));
        li.setGlobal("set_gain");
        li.pushFunction(ziglua.wrap(setWeightedStrength));
        li.setGlobal("set_weighted_strength");
        li.pushFunction(ziglua.wrap(setPingPongStrength));
        li.setGlobal("set_ping_pong_strength");

        li.pushFunction(ziglua.wrap(setNoiseType));
        li.setGlobal("set_noise_type");
        li.pushFunction(ziglua.wrap(setFractalType));
        li.setGlobal("set_fractal_type");
        li.pushFunction(ziglua.wrap(setCelluarDistanceFunc));
        li.setGlobal("set_cell_dist_func");
        li.pushFunction(ziglua.wrap(setCelluarReturnType));
        li.setGlobal("set_cell_return_type");
    }
    {
        li.pushInteger(0);
        li.setGlobal("NT_OPEN_SIMPLEX2");
        li.pushInteger(1);
        li.setGlobal("NT_OPEN_SIMPLEX2S");
        li.pushInteger(2);
        li.setGlobal("NT_CELLUAR");
        li.pushInteger(3);
        li.setGlobal("NT_PERLIN");
        li.pushInteger(4);
        li.setGlobal("NT_VALUE_CUBIC");
        li.pushInteger(5);
        li.setGlobal("NT_VALUE");

        li.pushInteger(0);
        li.setGlobal("FT_NONE");
        li.pushInteger(1);
        li.setGlobal("FT_FBM");
        li.pushInteger(2);
        li.setGlobal("FT_RIDGED");
        li.pushInteger(3);
        li.setGlobal("FT_PING_PONG");
        li.pushInteger(4);
        li.setGlobal("FT_DOMAIN_WARP_PROGRESSIVE");
        li.pushInteger(5);
        li.setGlobal("FT_DOMAIN_WARP_INDEPENDENT");

        li.pushInteger(0);
        li.setGlobal("CDF_EUCLIDEAN");
        li.pushInteger(1);
        li.setGlobal("CDF_EUCLIDEAN_SQ");
        li.pushInteger(2);
        li.setGlobal("CDF_MANHATTEN");
        li.pushInteger(3);
        li.setGlobal("CDF_HYBRID");

        li.pushInteger(0);
        li.setGlobal("CRT_CELL_VALUE");
        li.pushInteger(1);
        li.setGlobal("CRT_DISTANCE");
        li.pushInteger(2);
        li.setGlobal("CRT_DISTANCE_2");
        li.pushInteger(3);
        li.setGlobal("CRT_DISTANCE_2_ADD");
        li.pushInteger(4);
        li.setGlobal("CRT_DISTANCE_2_SUB");
        li.pushInteger(5);
        li.setGlobal("CRT_DISTANCE_2_MUL");
        li.pushInteger(6);
        li.setGlobal("CRT_DISTANCE_2_DIV");

        li.pushInteger(0);
        li.setGlobal("OP_EQ");
        li.pushInteger(1);
        li.setGlobal("OP_GT");
        li.pushInteger(2);
        li.setGlobal("OP_LT");
        li.pushInteger(3);
        li.setGlobal("OP_GTE");
        li.pushInteger(4);
        li.setGlobal("OP_LTE");

        // For rotation, for when this thing supports that again.
        li.pushInteger(0);
        li.setGlobal("RT_XY");
        li.pushInteger(1);
        li.setGlobal("RT_XZ");
        li.pushInteger(2);
        li.setGlobal("RT_NONE");
    }
}

const std = @import("std");
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const znoise = @import("znoise");
const block = @import("../block/block.zig");
const chunk = block.chunk;
const desc = chunk.descriptor;
