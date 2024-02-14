const gl = @import("zopengl");

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
    bgColor: [4]gl.Float = undefined,
};
