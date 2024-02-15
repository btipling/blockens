const gl = @import("zopengl");
const zm = @import("zmath");
const math = @import("../../math/math.zig");

pub const Plane = struct {
    color: math.vecs.Vflx4 = undefined,
    translate: [3]gl.Float,
};
