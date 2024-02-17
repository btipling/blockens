const gl = @import("zopengl");
const math = @import("../../math/math.zig");
pub const shape = @import("shape.zig");
pub const gfx = @import("gfx.zig");

pub const Time = struct {
    startTime: i64 = 0,
    currentTime: i64 = 0,
};

pub const Sky = struct {
    sun: SunState = .rising,
    lastSet: i64 = 0,
    pub const SunState = enum {
        rising,
        setting,
    };
};
