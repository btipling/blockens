const std = @import("std");
const zmesh = @import("zmesh");
const game = @import("../game.zig");
const game_mob = @import("../mob.zig");
const blecs = @import("../blecs/blecs.zig");

pub const meshData = struct {
    positions: [][3]f32 = undefined,
    indices: []u32 = undefined,
    texcoords: ?[][2]f32 = null,
    normals: ?[][3]f32 = null,
    edges: ?[][2]f32 = null,
    barycentric: ?[][3]f32 = null,

    pub fn deinit(self: *meshData) void {
        game.state.allocator.free(self.positions);
        game.state.allocator.free(self.indices);
        if (self.texcoords) |t| game.state.allocator.free(t);
        if (self.normals) |n| game.state.allocator.free(n);
        if (self.edges) |e| game.state.allocator.free(e);
        if (self.barycentric) |b| game.state.allocator.free(b);
    }
};

pub const meshDataVoxels = struct {
    positions: [36][3]f32,
    indices: [36]u32,
    texcoords: [36][2]f32,
    normals: [36][3]f32,

    pub fn toMeshData(self: meshDataVoxels) meshData {
        const positions: [][3]f32 = game.state.allocator.alloc([3]f32, self.positions.len) catch @panic("OOM");
        @memcpy(positions, &self.positions);
        const indices: []u32 = game.state.allocator.alloc(u32, self.indices.len) catch @panic("OOM");
        @memcpy(indices, &self.indices);
        const texcoords: [][2]f32 = game.state.allocator.alloc([2]f32, self.texcoords.len) catch @panic("OOM");
        @memcpy(texcoords, &self.texcoords);
        const normals: [][3]f32 = game.state.allocator.alloc([3]f32, self.normals.len) catch @panic("OOM");
        @memcpy(normals, &self.normals);
        return .{ .positions = positions, .indices = indices, .texcoords = texcoords, .normals = normals };
    }
};

// :: Plane
pub fn plane() meshData {
    var p = zmesh.Shape.initPlane(1, 1);
    defer p.deinit();
    const positions: [][3]f32 = game.state.allocator.alloc([3]f32, p.positions.len) catch @panic("OOM");
    @memcpy(positions, p.positions);
    const indices: []u32 = game.state.allocator.alloc(u32, p.indices.len) catch @panic("OOM");
    @memcpy(indices, p.indices);
    var texcoords: ?[][2]f32 = null;
    if (p.texcoords) |_| {
        const tc: [][2]f32 = game.state.allocator.alloc([2]f32, p.texcoords.?.len) catch @panic("OOM");
        @memcpy(tc, p.texcoords.?);
        texcoords = tc;
    }
    var normals: ?[][3]f32 = null;
    if (p.normals) |_| {
        const ns: [][3]f32 = game.state.allocator.alloc([3]f32, p.normals.?.len) catch @panic("OOM");
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
    .{ 0, 0.666 },
    .{ 1, 0.666 },
    .{ 1, 0.333 },
    .{ 0, 0.666 },
    .{ 1, 0.333 },
    .{ 0, 0.333 },
    // right
    .{ 0, 0.666 },
    .{ 1, 0.666 },
    .{ 1, 0.333 },
    .{ 0, 0.666 },
    .{ 1, 0.333 },
    .{ 0, 0.333 },
    // back
    .{ 0, 0.666 },
    .{ 1, 0.666 },
    .{ 1, 0.333 },
    .{ 0, 0.666 },
    .{ 1, 0.333 },
    .{ 0, 0.333 },
    // left
    .{ 0, 0.666 },
    .{ 1, 0.666 },
    .{ 1, 0.333 },
    .{ 0, 0.666 },
    .{ 1, 0.333 },
    .{ 0, 0.333 },
    // bottom
    .{ 0, 0.666 },
    .{ 1, 0.666 },
    .{ 1, 1 },
    .{ 0, 0.666 },
    .{ 1, 1 },
    .{ 0, 1 },
    // top
    .{ 0, 0 },
    .{ 1, 0 },
    .{ 1, 0.333 },
    .{ 0, 0 },
    .{ 1, 0.333 },
    .{ 0, 0.333 },
};

const edges: [36][2]f32 = .{
    // front
    .{ 0, 1 },
    .{ 1, 1 },
    .{ 1, 0 },
    .{ 0, 1 },
    .{ 1, 0 },
    .{ 0, 0 },
    // right
    .{ 0, 1 },
    .{ 1, 1 },
    .{ 1, 0 },
    .{ 0, 1 },
    .{ 1, 0 },
    .{ 0, 0 },
    // back
    .{ 0, 1 },
    .{ 1, 1 },
    .{ 1, 0 },
    .{ 0, 1 },
    .{ 1, 0 },
    .{ 0, 0 },
    // left
    .{ 0, 1 },
    .{ 1, 1 },
    .{ 1, 0 },
    .{ 0, 1 },
    .{ 1, 0 },
    .{ 0, 0 },
    // bottom
    .{ 0, 0 },
    .{ 1, 0 },
    .{ 1, 1 },
    .{ 0, 0 },
    .{ 1, 1 },
    .{ 0, 1 },
    // top
    .{ 0, 0 },
    .{ 1, 0 },
    .{ 1, 1 },
    .{ 0, 0 },
    .{ 1, 1 },
    .{ 0, 1 },
};

const barycentric_coordinates: [3][3]f32 = .{
    .{ 1.0, 0.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 0.0, 1.0 },
};

const cube_normals: [36][3]f32 = .{
    // front
    .{ 0, 0, 1 },
    .{ 0, 0, 1 },
    .{ 0, 0, 1 },
    .{ 0, 0, 1 },
    .{ 0, 0, 1 },
    .{ 0, 0, 1 },
    // right
    .{ 1, 0, 0 },
    .{ 1, 0, 0 },
    .{ 1, 0, 0 },
    .{ 1, 0, 0 },
    .{ 1, 0, 0 },
    .{ 1, 0, 0 },
    // backl
    .{ 0, 0, -1 },
    .{ 0, 0, -1 },
    .{ 0, 0, -1 },
    .{ 0, 0, -1 },
    .{ 0, 0, -1 },
    .{ 0, 0, -1 },
    // left
    .{ -1, 0, 0 },
    .{ -1, 0, 0 },
    .{ -1, 0, 0 },
    .{ -1, 0, 0 },
    .{ -1, 0, 0 },
    .{ -1, 0, 0 },
    // bottom
    .{ 0, -1, 0 },
    .{ 0, -1, 0 },
    .{ 0, -1, 0 },
    .{ 0, -1, 0 },
    .{ 0, -1, 0 },
    .{ 0, -1, 0 },
    // top
    .{ 0, 1, 0 },
    .{ 0, 1, 0 },
    .{ 0, 1, 0 },
    .{ 0, 1, 0 },
    .{ 0, 1, 0 },
    .{ 0, 1, 0 },
};

const bounding_box_positions: [36][3]f32 = .{
    // front
    .{ 0, 0, 1 },
    .{ 1, 0, 1 },
    .{ 1, 1, 1 },
    .{ 0, 0, 1 },
    .{ 1, 1, 1 },
    .{ 0, 1, 1 },

    // right
    .{ 1, 0, 1 },
    .{ 1, 0, 0 },
    .{ 1, 1, 0 },
    .{ 1, 0, 1 },
    .{ 1, 1, 0 },
    .{ 1, 1, 1 },
    // back
    .{ 1, 0, 0 },
    .{ 0, 0, 0 },
    .{ 0, 1, 0 },
    .{ 1, 0, 0 },
    .{ 0, 1, 0 },
    .{ 1, 1, 0 },
    // left
    .{ 0, 0, 0 },
    .{ 0, 0, 1 },
    .{ 0, 1, 1 },
    .{ 0, 0, 0 },
    .{ 0, 1, 1 },
    .{ 0, 1, 0 },
    // bottom
    .{ 0, 0, 0 },
    .{ 1, 0, 0 },
    .{ 1, 0, 1 },
    .{ 0, 0, 0 },
    .{ 1, 0, 1 },
    .{ 0, 0, 1 },
    // top
    .{ 0, 1, 1 },
    .{ 1, 1, 1 },
    .{ 1, 1, 0 },
    .{ 0, 1, 1 },
    .{ 1, 1, 0 },
    .{ 0, 1, 0 },
};

const sub_chunk_positions: [3][3]f32 = .{
    .{ -0.5, -0.5, 0.5 },
    .{ 0.5, -0.5, 0.5 },
    .{ 0.5, 0.5, 0.5 },
};

pub fn cube() meshData {
    const positions: [][3]f32 = game.state.allocator.alloc([3]f32, cube_positions.len) catch @panic("OOM");
    @memcpy(positions, &cube_positions);
    const indices: []u32 = game.state.allocator.alloc(u32, cube_indices.len) catch @panic("OOM");
    @memcpy(indices, &cube_indices);
    const texcoords: [][2]f32 = game.state.allocator.alloc([2]f32, cube_texcoords.len) catch @panic("OOM");
    @memcpy(texcoords, &cube_texcoords);
    const normals: [][3]f32 = game.state.allocator.alloc([3]f32, cube_normals.len) catch @panic("OOM");
    @memcpy(normals, &cube_normals);
    return .{ .positions = positions, .indices = indices, .texcoords = texcoords, .normals = normals };
}

pub var voxel_mesh_creator: VoxelMeshCreator = undefined;
const vmc_k = struct {
    x: usize,
    y: usize,
    z: usize,
};

pub fn init() void {
    voxel_mesh_creator = VoxelMeshCreator.init();
}
pub fn deinit() void {
    voxel_mesh_creator.deinit();
}

pub const VoxelMeshCreator = struct {
    cache: std.AutoHashMap(vmc_k, meshDataVoxels),
    mutex: std.Thread.Mutex,
    pub fn init() VoxelMeshCreator {
        return .{
            .cache = std.AutoHashMap(vmc_k, meshDataVoxels).init(game.state.allocator),
            .mutex = .{},
        };
    }
    pub fn deinit(self: *VoxelMeshCreator) void {
        self.cache.deinit();
    }

    fn scaleToKey(_: VoxelMeshCreator, scale: @Vector(4, f32)) vmc_k {
        const uis: @Vector(4, u32) = @intFromFloat(scale);
        return .{
            .x = uis[0],
            .y = uis[1],
            .z = uis[2],
        };
    }

    pub fn voxel(self: *VoxelMeshCreator, scale: @Vector(4, f32)) !meshDataVoxels {
        self.mutex.lock();
        defer self.mutex.unlock();
        const k = self.scaleToKey(scale);
        if (self.cache.get(k)) |mdv| return mdv;
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

        var positions: [36][3]f32 = std.mem.zeroes([36][3]f32);
        @memcpy(&positions, v.positions);
        var indices: [36]u32 = std.mem.zeroes([36]u32);
        @memcpy(&indices, v.indices);
        var texcoords: [36][2]f32 = std.mem.zeroes([36][2]f32);
        @memcpy(&texcoords, v.texcoords.?);
        var normals: [36][3]f32 = std.mem.zeroes([36][3]f32);
        @memcpy(&normals, v.normals.?);
        const rv: meshDataVoxels = .{ .positions = positions, .indices = indices, .texcoords = texcoords, .normals = normals };
        self.cache.put(k, rv) catch @panic("OOM");
        return rv;
    }
};

pub fn mob(world: *blecs.ecs.world_t, entity: blecs.ecs.entity_t) meshData {
    if (!blecs.ecs.has_id(world, entity, blecs.ecs.id(blecs.components.mob.Mesh))) return cube();
    const mesh_c: *const blecs.components.mob.Mesh = blecs.ecs.get(world, entity, blecs.components.mob.Mesh).?;
    if (!blecs.ecs.has_id(world, mesh_c.mob_entity, blecs.ecs.id(blecs.components.mob.Mob))) return cube();
    const mob_c: *const blecs.components.mob.Mob = blecs.ecs.get(world, mesh_c.mob_entity, blecs.components.mob.Mob).?;
    if (!game.state.gfx.mob_data.contains(mob_c.mob_id)) return cube();
    const mob_data: *game_mob.Mob = game.state.gfx.mob_data.get(mob_c.mob_id).?;
    if (mob_data.meshes.items.len <= mesh_c.mesh_id) return cube();
    const mesh: *game_mob.MobMesh = mob_data.meshes.items[mesh_c.mesh_id];
    const positions: [][3]f32 = game.state.allocator.alloc([3]f32, mesh.positions.items.len) catch @panic("OOM");
    @memcpy(positions, mesh.positions.items);
    const indices: []u32 = game.state.allocator.alloc(u32, mesh.indices.items.len) catch @panic("OOM");
    @memcpy(indices, mesh.indices.items);
    var texcoords: ?[][2]f32 = null;
    if (mesh.texture != null) {
        var tc = game.state.allocator.alloc([2]f32, mesh.textcoords.items.len) catch @panic("OOM");
        _ = &tc;
        @memcpy(tc, mesh.textcoords.items);
        texcoords = tc;
    }
    const normals: [][3]f32 = game.state.allocator.alloc([3]f32, mesh.normals.items.len) catch @panic("OOM");
    @memcpy(normals, mesh.normals.items);
    return .{ .positions = positions, .indices = indices, .texcoords = texcoords, .normals = normals };
}

// bounding_box: just return positions and indicies and just draw box edges around a mob
// Just cuboids atm, no complex bounding boxes.
pub fn bounding_box(mob_id: i32) meshData {
    const scale: [3]f32 = switch (mob_id) {
        0 => .{ 1, 1, 1 }, // bounding box for a cube
        1 => .{ 1, 2.25, 1 },
        else => std.debug.panic("Unexpected mob id in bounding box mesh lookup {d}\n", .{mob_id}),
    };
    const translate: [3]f32 = switch (mob_id) {
        0 => .{ 0, 0, 0 }, // bounding box for a cube
        1 => .{ -0.5, 0, -0.5 },
        else => std.debug.panic("Unexpected mob id in bounding box mesh lookup {d}\n", .{mob_id}),
    };
    const positions: [][3]f32 = game.state.allocator.alloc([3]f32, bounding_box_positions.len) catch @panic("OOM");
    @memcpy(positions, &bounding_box_positions);
    for (0..positions.len) |i| {
        for (0..positions[i].len) |ii| {
            positions[i][ii] *= scale[ii];
            positions[i][ii] += translate[ii];
        }
    }
    const indices: []u32 = game.state.allocator.alloc(u32, cube_indices.len) catch @panic("OOM");
    @memcpy(indices, &cube_indices);
    const e: [][2]f32 = game.state.allocator.alloc([2]f32, edges.len) catch @panic("OOM");
    @memcpy(e, &edges);
    const bc: [][3]f32 = game.state.allocator.alloc([3]f32, barycentric_coordinates.len) catch @panic("OOM");
    @memcpy(bc, &barycentric_coordinates);
    return .{ .positions = positions, .indices = indices, .edges = e, .barycentric = bc };
}

pub fn block_highlight() meshData {
    const positions: [][3]f32 = game.state.allocator.alloc([3]f32, cube_positions.len) catch @panic("OOM");
    @memcpy(positions, &cube_positions);
    const scale: [3]f32 = .{ 1.1, 1.1, 1.1 };
    const translate: [3]f32 = .{ 0.5, 0.5, 0.5 };
    for (0..positions.len) |i| {
        for (0..positions[i].len) |ii| {
            positions[i][ii] *= scale[ii];
            positions[i][ii] += translate[ii];
        }
    }
    const indices: []u32 = game.state.allocator.alloc(u32, cube_indices.len) catch @panic("OOM");
    @memcpy(indices, &cube_indices);
    const e: [][2]f32 = game.state.allocator.alloc([2]f32, edges.len) catch @panic("OOM");
    @memcpy(e, &edges);
    const bc: [][3]f32 = game.state.allocator.alloc([3]f32, barycentric_coordinates.len) catch @panic("OOM");
    @memcpy(bc, &barycentric_coordinates);
    return .{ .positions = positions, .indices = indices, .edges = e, .barycentric = bc };
}
