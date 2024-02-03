const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const position = @import("position.zig");
const state = @import("state.zig");
const cube = @import("../shape/cube.zig");
const shapeview = @import("../shape/view.zig");
const data = @import("../data/data.zig");
const chunk = @import("../chunk.zig");
const instancedShape = @import("../shape/instanced_shape.zig");
const voxelMesh = @import("../shape/voxel_mesh.zig");

pub const Screens = enum {
    game,
    textureGenerator,
    worldEditor,
    blockEditor,
    chunkGenerator,
    characterDesigner,
    paused,
};

pub const defaultScreen = Screens.game;

pub const Character = struct {
    alloc: std.mem.Allocator,
    wireframe: bool = false,
    pub fn init(
        alloc: std.mem.Allocator,
    ) !Character {
        return Character{
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Character) void {
        _ = self;
    }
};
