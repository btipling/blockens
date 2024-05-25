const std = @import("std");
const zm = @import("zmath");
const gfx = @import("gfx/gfx.zig");
const game = @import("game.zig");

pub const MobCamera = struct {
    // TODO: add camera name and deinit
    aspectRatio: f32 = 1,
    yfov: f32 = 1,
    znear: f32 = 1,
    zfar: f32 = 500,
};

pub const MobAnimation = struct {
    frame: f32 = 0,
    scale: ?@Vector(4, f32) = null,
    rotation: ?@Vector(4, f32) = null,
    translation: ?@Vector(4, f32) = null,
};

pub const MobMesh = struct {
    id: usize = 0,
    parent: ?usize = null,
    transform: ?zm.Mat = null,
    indices: std.ArrayList(u32),
    positions: std.ArrayList([3]f32),
    normals: std.ArrayList([3]f32),
    textcoords: std.ArrayList([2]f32),
    tangents: std.ArrayList([4]f32),
    animations: ?std.ArrayList(MobAnimation) = null,
    scale: ?@Vector(4, f32) = null,
    rotation: ?@Vector(4, f32) = null,
    translation: ?@Vector(4, f32) = null,
    color: @Vector(4, f32) = .{ 1.0, 0.0, 1.0, 1.0 },
    texture: ?[]u8 = null,

    pub fn init(
        allocator: std.mem.Allocator,
        id: usize,
        parent: ?usize,
        color: @Vector(4, f32),
        texture: ?[]u8,
        animations: ?std.ArrayList(MobAnimation),
    ) *MobMesh {
        var m: *MobMesh = allocator.create(MobMesh) catch @panic("OOM");
        _ = &m;
        m.* = .{
            .indices = std.ArrayList(u32).init(allocator),
            .positions = std.ArrayList([3]f32).init(allocator),
            .normals = std.ArrayList([3]f32).init(allocator),
            .textcoords = std.ArrayList([2]f32).init(allocator),
            .tangents = std.ArrayList([4]f32).init(allocator),
            .id = id,
            .parent = parent,
            .color = color,
            .texture = texture,
            .animations = animations,
        };
        return m;
    }

    fn deinit(self: MobMesh, allocator: std.mem.Allocator) void {
        self.indices.deinit();
        self.positions.deinit();
        self.normals.deinit();
        self.textcoords.deinit();
        self.tangents.deinit();
        if (self.animations) |a| a.deinit();
        if (self.texture) |t| allocator.free(t);
    }
};

pub const Mob = struct {
    id: i32,
    meshes: std.ArrayList(*MobMesh) = undefined,
    // 0 - 6 front
    // 6 - 12 right
    // 12 - 18 back
    // 18 - 24 left
    // 24 - 30 bottom
    // 30 - 36 top
    bounding_box: ?[][3]f32 = null,
    bounding_box_uniques: ?[][3]f32 = null,
    cameras: ?std.ArrayList(MobCamera) = null,
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator, id: i32, num_meshes: usize) *Mob {
        var m: *Mob = allocator.create(Mob) catch @panic("OOM");
        _ = &m;
        var meshes = std.ArrayList(*MobMesh).initCapacity(
            allocator,
            num_meshes,
        ) catch @panic("OOM");
        meshes.expandToCapacity();
        m.* = .{
            .id = id,
            .meshes = meshes,
            .allocator = allocator,
        };
        m.loadBoundingBox();
        return m;
    }

    pub fn deinit(self: *Mob) void {
        for (self.meshes.items) |m| {
            m.deinit(self.allocator);
            self.allocator.destroy(m);
        }
        self.meshes.deinit();
        if (self.bounding_box) |b| self.allocator.free(b);
        if (self.bounding_box_uniques) |b| self.allocator.free(b);
    }

    fn loadBoundingBox(self: *Mob) void {
        var data: gfx.mesh.meshData = gfx.mesh.bounding_box(self.id);
        defer data.deinit();
        const positions: [][3]f32 = game.state.allocator.alloc([3]f32, data.positions.len) catch @panic("OOM");
        @memcpy(positions, data.positions);
        self.bounding_box = positions;
        const num_unique_vertices_in_cuboid = 8;
        const unique_positions: [][3]f32 = game.state.allocator.alloc([3]f32, num_unique_vertices_in_cuboid) catch @panic("OOM");
        // just get unique bounds based on how they're defined in gfx/mesh.zig
        // zig fmt: off
        unique_positions[0] = data.positions[13]; // .{ 0, 0, 0 }
        unique_positions[1] = data.positions[0];  // .{ 0, 0, n }
        unique_positions[2] = data.positions[14]; // .{ 0, n, 0 }
        unique_positions[3] = data.positions[5];  // .{ 0, n, n }
        unique_positions[4] = data.positions[12]; // .{ n, 0, 0 }
        unique_positions[5] = data.positions[1];  // .{ n, 0, n }
        unique_positions[6] = data.positions[8];  // .{ n, n, 0 }
        unique_positions[7] = data.positions[4];  // .{ n, n, n }
        // zig fmt: on
        self.bounding_box_uniques = unique_positions;
    }

    pub fn getBottomBounds(self: *const Mob) []const [3]f32 {
        const bb = self.bounding_box orelse @panic("nope");
        // 24 - 30 bottom
        return bb[24..30];
    }

    pub fn getTopBounds(self: *const Mob) []const [3]f32 {
        const bb = self.bounding_box orelse @panic("nope");
        // 30 - 36 top
        return bb[30..36];
    }

    pub fn getAllBounds(self: *const Mob) []const [3]f32 {
        return self.bounding_box_uniques orelse @panic("nope");
    }
};
