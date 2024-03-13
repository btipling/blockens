const std = @import("std");
const zmesh = @import("zmesh");
const game = @import("../game.zig");
const state = @import("../state.zig");
const blecs = @import("../blecs/blecs.zig");

pub const meshData = struct {
    positions: [][3]f32,
    indices: []u32,
    texcoords: ?[][2]f32 = null,
    normals: ?[][3]f32 = null,
};

// :: Plane
pub fn plane() meshData {
    var p = zmesh.Shape.initPlane(1, 1);
    defer p.deinit();
    const positions: [][3]f32 = game.state.allocator.alloc([3]f32, p.positions.len) catch unreachable;
    @memcpy(positions, p.positions);
    const indices: []u32 = game.state.allocator.alloc(u32, p.indices.len) catch unreachable;
    @memcpy(indices, p.indices);
    var texcoords: ?[][2]f32 = null;
    if (p.texcoords) |_| {
        const tc: [][2]f32 = game.state.allocator.alloc([2]f32, p.texcoords.?.len) catch unreachable;
        @memcpy(tc, p.texcoords.?);
        texcoords = tc;
    }
    var normals: ?[][3]f32 = null;
    if (p.normals) |_| {
        const ns: [][3]f32 = game.state.allocator.alloc([3]f32, p.normals.?.len) catch unreachable;
        @memcpy(ns, p.normals.?);
        normals = ns;
    }
    return .{ .positions = positions, .indices = indices, .texcoords = texcoords, .normals = normals };
}

// :: Cube
const cube_positions: [36][3]f32 = .{
    // front
    .{ -0.5, -0.5, 0.5 },
    .{ 0.5, -0.5, 0.5 },
    .{ 0.5, 0.5, 0.5 },
    .{ -0.5, -0.5, 0.5 },
    .{ 0.5, 0.5, 0.5 },
    .{ -0.5, 0.5, 0.5 },

    // right
    .{ 0.5, -0.5, 0.5 },
    .{ 0.5, -0.5, -0.5 },
    .{ 0.5, 0.5, -0.5 },
    .{ 0.5, -0.5, 0.5 },
    .{ 0.5, 0.5, -0.5 },
    .{ 0.5, 0.5, 0.5 },
    // back
    .{ 0.5, -0.5, -0.5 },
    .{ -0.5, -0.5, -0.5 },
    .{ -0.5, 0.5, -0.5 },
    .{ 0.5, -0.5, -0.5 },
    .{ -0.5, 0.5, -0.5 },
    .{ 0.5, 0.5, -0.5 },
    // left
    .{ -0.5, -0.5, -0.5 },
    .{ -0.5, -0.5, 0.5 },
    .{ -0.5, 0.5, 0.5 },
    .{ -0.5, -0.5, -0.5 },
    .{ -0.5, 0.5, 0.5 },
    .{ -0.5, 0.5, -0.5 },
    // bottom
    .{ -0.5, -0.5, -0.5 },
    .{ 0.5, -0.5, -0.5 },
    .{ 0.5, -0.5, 0.5 },
    .{ -0.5, -0.5, -0.5 },
    .{ 0.5, -0.5, 0.5 },
    .{ -0.5, -0.5, 0.5 },
    // top
    .{ -0.5, 0.5, 0.5 },
    .{ 0.5, 0.5, 0.5 },
    .{ 0.5, 0.5, -0.5 },
    .{ -0.5, 0.5, 0.5 },
    .{ 0.5, 0.5, -0.5 },
    .{ -0.5, 0.5, -0.5 },
};

const cube_indices: [36]u32 = .{
    0, 1, 2, 3, 4, 5, // front
    6, 7, 8, 9, 10, 11, // right
    12, 13, 14, 15, 16, 17, // back
    18, 19, 20, 21, 22, 23, // left
    24, 25, 26, 27, 28, 29, // bottom
    30, 31, 32, 33, 34, 35, // top
};

const cube_texcoords: [36][2]f32 = .{
    // front
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
    // right
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
    // back
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
    // left
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.666 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
    // bottom
    .{ 0.0, 0.666 },
    .{ 1.0, 0.666 },
    .{ 1.0, 1.0 },
    .{ 0.0, 0.666 },
    .{ 1.0, 1.0 },
    .{ 0.0, 1.0 },
    // top
    .{ 0.0, 0.0 },
    .{ 1.0, 0.0 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.0 },
    .{ 1.0, 0.333 },
    .{ 0.0, 0.333 },
};

const cube_normals: [36][3]f32 = .{
    // front
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0 },
    // right
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    .{ 1.0, 0.0, 0.0 },
    // backl
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    .{ 0.0, 0.0, -1.0 },
    // left
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    .{ -1.0, 0.0, 0.0 },
    // bottom
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    .{ 0.0, -1.0, 0.0 },
    // top
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
};

pub fn cube() meshData {
    const positions: [][3]f32 = game.state.allocator.alloc([3]f32, cube_positions.len) catch unreachable;
    @memcpy(positions, &cube_positions);
    const indices: []u32 = game.state.allocator.alloc(u32, cube_indices.len) catch unreachable;
    @memcpy(indices, &cube_indices);
    const texcoords: [][2]f32 = game.state.allocator.alloc([2]f32, cube_texcoords.len) catch unreachable;
    @memcpy(texcoords, &cube_texcoords);
    const normals: [][3]f32 = game.state.allocator.alloc([3]f32, cube_normals.len) catch unreachable;
    @memcpy(normals, &cube_normals);
    return .{ .positions = positions, .indices = indices, .texcoords = texcoords, .normals = normals };
}

pub fn voxel(scale: @Vector(4, f32)) !meshData {
    const allocator = game.state.allocator;
    var indicesAL = std.ArrayList(u32).init(allocator);

    defer indicesAL.deinit();
    var _i = cube_indices;
    try indicesAL.appendSlice(&_i);

    var positionsAL = std.ArrayList([3]f32).init(allocator);
    defer positionsAL.deinit();
    var _p = cube_positions;
    try positionsAL.appendSlice(&_p);

    var normalsAL = std.ArrayList([3]f32).init(allocator);
    defer normalsAL.deinit();
    var _n = cube_normals;
    try normalsAL.appendSlice(&_n);

    var texcoordsAL = std.ArrayList([2]f32).init(allocator);
    defer texcoordsAL.deinit();
    var _t = cube_texcoords;
    try texcoordsAL.appendSlice(&_t);

    var v = zmesh.Shape.init(indicesAL, positionsAL, normalsAL, texcoordsAL);
    defer v.deinit();

    // voxel meshes are centered around origin and range fro -0.5 to 0.5 so need a translation
    v.translate(0.5, 0.5, 0.5);
    v.scale(scale[0], scale[1], scale[2]);
    v.translate(0.5, 0.5, 0.5);

    const positions: [][3]f32 = game.state.allocator.alloc([3]f32, v.positions.len) catch unreachable;
    @memcpy(positions, v.positions);
    const indices: []u32 = game.state.allocator.alloc(u32, v.indices.len) catch unreachable;
    @memcpy(indices, v.indices);
    const texcoords: [][2]f32 = game.state.allocator.alloc([2]f32, v.texcoords.?.len) catch unreachable;
    @memcpy(texcoords, v.texcoords.?);
    const normals: [][3]f32 = game.state.allocator.alloc([3]f32, v.normals.?.len) catch unreachable;
    @memcpy(normals, v.normals.?);
    return .{ .positions = positions, .indices = indices, .texcoords = texcoords, .normals = normals };
}

pub fn mob(world: *blecs.ecs.world_t, entity: blecs.ecs.entity_t) meshData {
    if (!blecs.ecs.has_id(world, entity, blecs.ecs.id(blecs.components.mob.Mesh))) return cube();
    const mesh_c: *const blecs.components.mob.Mesh = blecs.ecs.get(world, entity, blecs.components.mob.Mesh).?;
    if (!blecs.ecs.has_id(world, mesh_c.mob_entity, blecs.ecs.id(blecs.components.mob.Mob))) return cube();
    const mob_c: *const blecs.components.mob.Mob = blecs.ecs.get(world, mesh_c.mob_entity, blecs.components.mob.Mob).?;
    if (!game.state.gfx.mob_data.contains(mob_c.mob_id)) return cube();
    const mob_data: *state.Mob = game.state.gfx.mob_data.get(mob_c.mob_id).?;
    if (mob_data.meshes.items.len <= mesh_c.mesh_id) return cube();
    const mesh: *state.MobMesh = mob_data.meshes.items[mesh_c.mesh_id];
    const positions: [][3]f32 = game.state.allocator.alloc([3]f32, mesh.positions.items.len) catch unreachable;
    @memcpy(positions, mesh.positions.items);
    const indices: []u32 = game.state.allocator.alloc(u32, mesh.indices.items.len) catch unreachable;
    @memcpy(indices, mesh.indices.items);
    var texcoords: ?[][2]f32 = null;
    if (mesh.texture != null) {
        var tc = game.state.allocator.alloc([2]f32, mesh.textcoords.items.len) catch unreachable;
        _ = &tc;
        @memcpy(tc, mesh.textcoords.items);
        texcoords = tc;
    }
    const normals: [][3]f32 = game.state.allocator.alloc([3]f32, mesh.normals.items.len) catch unreachable;
    @memcpy(normals, mesh.normals.items);
    return .{ .positions = positions, .indices = indices, .texcoords = texcoords, .normals = normals };
}