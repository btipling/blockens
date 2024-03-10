const std = @import("std");
const zm = @import("zmath");

pub const Vflx4 = struct {
    value: zm.F32x4 = undefined,
    arr: [4]f32 = undefined,
    buffer: [100]u8 = [_]u8{0} ** 100,

    pub fn initFloats(v0: f32, v1: f32, v2: f32, v3: f32) Vflx4 {
        var v = Vflx4{};
        v.set(v0, v1, v2, v3);
        return v;
    }

    pub fn initBytes(v0: u8, v1: u8, v2: u8, v3: u8) Vflx4 {
        var v = Vflx4{};
        v.set(
            @as(f32, @floatFromInt(v0)) / 255,
            @as(f32, @floatFromInt(v1)) / 255,
            @as(f32, @floatFromInt(v2)) / 255,
            @as(f32, @floatFromInt(v3)) / 255,
        );
        return v;
    }

    pub fn set(self: *Vflx4, v0: f32, v1: f32, v2: f32, v3: f32) void {
        return self.setVec(zm.f32x4(v0, v1, v2, v3));
    }

    pub fn setVec(self: *Vflx4, v: zm.F32x4) void {
        self.value = v;
        zm.storeArr4(&self.arr, self.value);
        self.buffer = [_]u8{0} ** 100;
    }

    pub fn setBrightness(self: *Vflx4, br: f32) void {
        var hsl = zm.rgbToHsl(self.value);
        hsl[2] = br;
        const rgb = zm.hslToRgb(hsl);
        self.set(rgb[0], rgb[1], rgb[2], rgb[3]);
    }

    pub fn setHue(self: *Vflx4, hue: f32) void {
        var hsl = zm.rgbToHsl(self.value);
        hsl[0] = hue;
        const rgb = zm.hslToRgb(hsl);
        self.set(rgb[0], rgb[1], rgb[2], rgb[3]);
    }

    pub fn getBrightness(self: *Vflx4) f32 {
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
