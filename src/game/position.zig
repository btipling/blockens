const std = @import("std");
const gl = @import("zopengl");

pub const Position = struct {
    x: gl.Float,
    y: gl.Float,
    z: gl.Float,
};

pub const Rotation = struct {
    x: gl.Float,
    y: gl.Float,
    z: gl.Float,
};
