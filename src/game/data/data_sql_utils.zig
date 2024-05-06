pub const DataErr = error{
    NotFound,
};

pub const scriptOptionSQL = struct {
    id: i32,
    name: sqlite.Text,
};

pub const scriptSQL = struct {
    id: i32,
    name: sqlite.Text,
    script: sqlite.Text,
};

pub const scriptOption = struct {
    id: i32,
    name: [21]u8,
};

pub const script = struct {
    id: i32,
    name: [21]u8,
    script: [360_001]u8,
};

pub const colorScriptOptionSQL = struct {
    id: i32,
    name: sqlite.Text,
    color: i32,
};

pub const colorScriptSQL = struct {
    id: i32,
    name: sqlite.Text,
    script: sqlite.Text,
    color: i32,
};

pub const colorScriptOption = struct {
    id: i32,
    name: [21:0]u8,
    color: [3]f32,
};

pub const colorScript = struct {
    id: i32,
    name: [21]u8,
    script: [360_001]u8,
    color: [3]f32,
};

pub fn sqlNameToArray(name: sqlite.Text) [21:0]u8 {
    var n: [21:0]u8 = [_:0]u8{0} ** 21;
    for (name.data, 0..) |c, i| {
        n[i] = c;
        if (c == 0) {
            break;
        }
    }
    return n;
}

pub fn sqlTextToScript(text: sqlite.Text) [360_001]u8 {
    var n: [360_001]u8 = [_]u8{0} ** 360_001;
    for (text.data, 0..) |c, i| {
        n[i] = c;
    }
    return n;
}

pub fn colorToInteger3(color: [3]f32) i32 {
    const c: [4]f32 = .{ color[0], color[1], color[2], 1.0 };
    return colorToInteger4(c);
}

pub fn integerToColor3(color: i32) [3]f32 {
    const c: [4]f32 = integerToColor4(color);
    return .{ c[0], c[1], c[2] };
}

pub fn colorToInteger4(color: [4]f32) i32 {
    const a = @as(i32, @intFromFloat(color[3] * 255.0));
    const b = @as(i32, @intFromFloat(color[2] * 255.0));
    const g = @as(i32, @intFromFloat(color[1] * 255.0));
    const r = @as(i32, @intFromFloat(color[0] * 255.0));
    const rv: i32 = a << 24 | b << 16 | g << 8 | r;
    return rv;
}

fn integerToColor4(color: i32) [4]f32 {
    const a = @as(f32, @floatFromInt(color >> 24 & 0xFF)) / 255.0;
    const b = @as(f32, @floatFromInt(color >> 16 & 0xFF)) / 255.0;
    const g = @as(f32, @floatFromInt(color >> 8 & 0xFF)) / 255.0;
    const r = @as(f32, @floatFromInt(color & 0xFF)) / 255.0;
    return .{ r, g, b, a };
}

const sqlite = @import("sqlite");
