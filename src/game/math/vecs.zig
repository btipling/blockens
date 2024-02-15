const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl");

pub const Vflx3 = struct {
    value: zm.F32x3 = undefined,
    arr: [3]gl.Float = undefined,

    pub fn init(v0: gl.Float, v1: gl.Float, v2: gl.Float) Vflx3 {
        var v = Vflx3{};
        v.set(v0, v1, v2);
        return v;
    }

    pub fn set(self: Vflx4, v0: gl.Float, v1: gl.Float, v2: gl.Float) void {
        self.value = zm.f32x3(v0, v1, v2);
        zm.storeArr3(&self.arr, self.value);
    }
};

pub const Vflx4 = struct {
    value: zm.F32x4 = undefined,
    arr: [4]gl.Float = undefined,
    buffer: [100]u8 = [_]u8{0} ** 100,

    pub fn init(v0: gl.Float, v1: gl.Float, v2: gl.Float, v3: gl.Float) Vflx4 {
        var v = Vflx4{};
        v.set(v0, v1, v2, v3);
        return v;
    }

    pub fn set(self: *Vflx4, v0: gl.Float, v1: gl.Float, v2: gl.Float, v3: gl.Float) void {
        self.value = zm.f32x4(v0, v1, v2, v3);
        zm.storeArr4(&self.arr, self.value);
        self.buffer = [_]u8{0} ** 100;
    }

    pub fn setBrightness(self: *Vflx4, br: gl.Float) void {
        var hsl = zm.rgbToHsl(self.value);
        hsl[2] = br;
        const rgb = zm.hslToRgb(hsl);
        self.set(rgb[0], rgb[1], rgb[2], rgb[3]);
    }

    pub fn getBrightness(self: *Vflx4) gl.Float {
        const hsl = zm.rgbToHsl(self.value);
        return hsl[2];
    }

    pub fn print(self: *Vflx4) []u8 {
        return std.fmt.bufPrint(
            &self.buffer,
            "({d}, {d}, {d}, {d})",
            .{ self.arr[0], self.arr[1], self.arr[2], self.arr[3] },
        ) catch return &self.buffer;
    }
};
