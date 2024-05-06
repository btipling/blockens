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

const sqlite = @import("sqlite");
