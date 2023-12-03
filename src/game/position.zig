const std = @import("std");
const gl = @import("zopengl");

pub const Position = struct {
    worldX: gl.Float,
    worldY: gl.Float,
    worldZ: gl.Float,
};
