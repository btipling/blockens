const gl = @import("zopengl");
const zm = @import("zmath");
const math = @import("../../math/math.zig");

pub const Plane = struct {
    color: ?math.vecs.Vflx4 = null,
    translate: ?math.vecs.Vflx3 = null,
    scale: ?math.vecs.Vflx3 = null,
    rotation: ?math.vecs.Vflx4 = null,
};

// Tags
pub const NeedsSetup = struct {};
