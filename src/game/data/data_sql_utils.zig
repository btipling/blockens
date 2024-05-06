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

const sqlite = @import("sqlite");
