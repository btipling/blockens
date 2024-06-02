n: @Vector(4, f32),

const plane = @This();

pub fn dot(self: plane, v: @Vector(4, f32)) f32 {
    return zm.dot4(self.n, v)[0];
}

const zm = @import("zmath");
