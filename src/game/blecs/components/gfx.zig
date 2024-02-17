const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const math = @import("../../math/math.zig");

pub const BaseRenderer = struct {
    clear: gl.Bitfield = 0,
    bgColor: math.vecs.Vflx4 = undefined,
};

pub const ElementsRendererConfig = struct {
    vertexShader: [:0]u8 = undefined,
    fragmentShader: [:0]u8 = undefined,
    positions: ?std.ArrayList([3]gl.Float) = null,
};

pub const ElementsRenderer = struct {
    program: gl.Uint = 0,
    vao: gl.Uint = 0,
    vbo: gl.Uint = 0,
    vertexShader: gl.Uint = 0,
    fragmentShader: gl.Uint = 0,
};

// Tags
pub const CanDraw = struct {};
