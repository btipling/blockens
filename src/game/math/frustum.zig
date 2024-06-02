planes: [6]plane = undefined,

const frustum = @This();

pub fn init(view: zm.Mat, fovy: f32, s: f32, near: f32, far: f32) frustum {
    const g = std.math.tan((fovy * std.math.pi / 360.0)) * s;
    const mx: f32 = 1.0 / @sqrt(g * g + s * s);
    const my: f32 = 1.0 / @sqrt(g * g + 1.0);
    const inverse_view = zm.inverse(view);

    var f: frustum = .{};

    const n0: @Vector(4, f32) = .{ -g * mx, 0, s * mx, 0 };
    f.planes[0] = .{ .n = zm.mul(n0, inverse_view) };
    const n1: @Vector(4, f32) = .{ 0, g * my, my, 0 };
    f.planes[1] = .{ .n = zm.mul(n1, inverse_view) };
    const n2: @Vector(4, f32) = .{ g * mx, 0, s * mx, 0 };
    f.planes[2] = .{ .n = zm.mul(n2, inverse_view) };
    const n3: @Vector(4, f32) = .{ 0, -g * my, my, 0 };
    f.planes[3] = .{ .n = zm.mul(n3, inverse_view) };

    const d: f32 = zm.dot4(view[2], view[3])[0];
    const n4: @Vector(4, f32) = .{ view[2][0], view[2][1], view[3][2], -(d + near) };
    f.planes[4] = .{ .n = n4 };
    const n5: @Vector(4, f32) = .{ -view[2][0], -view[2][1], -view[3][2], d + far };
    f.planes[5] = .{ .n = n5 };
    return f;
}

pub fn axisAlignedBoxVisible(self: frustum, center: @Vector(4, f32), size: @Vector(4, f32)) bool {
    var i: usize = 0;
    while (i < self.planes.len) : (i += 1) {
        const g: plane = self.planes[i];
        const rg: f32 = @abs(g.n[0] * size[0]) + @abs(g.n[1] * size[1]) + @abs(g.n[2] * size[2]);
        if (g.dot(center) <= -rg) return false;
    }

    return true;
}

const std = @import("std");
const zm = @import("zmath");
const plane = @import("plane.zig");
