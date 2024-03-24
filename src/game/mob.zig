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
        var m: *MobMesh = allocator.create(MobMesh) catch unreachable;
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
    cameras: ?std.ArrayList(MobCamera) = null,
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator, id: i32, num_meshes: usize) *Mob {
        var m: *Mob = allocator.create(Mob) catch unreachable;
        _ = &m;
        var meshes = std.ArrayList(*MobMesh).initCapacity(
            allocator,
            num_meshes,
        ) catch unreachable;
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
    }

    fn loadBoundingBox(self: *Mob) void {
        var data: gfx.mesh.meshData = gfx.mesh.bounding_box(self.id);
        defer data.deinit();
        const positions: [][3]f32 = game.state.allocator.alloc([3]f32, data.positions.len) catch unreachable;
        @memcpy(positions, data.positions);
        self.bounding_box = positions;
    }

    pub fn getBottomBounds(self: *const Mob) [][3]f32 {
        // 24 - 30 bottom
        return self.bounding_box.?[24..30];
    }
};
