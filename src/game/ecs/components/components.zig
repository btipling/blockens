const gl = @import("zopengl");
const math = @import("../../math/math.zig");

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

pub const BaseRenderer = struct {
    clear: gl.Bitfield = 0,
    bgColor: math.vecs.Vflx4 = undefined,
};
