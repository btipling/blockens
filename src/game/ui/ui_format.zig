pub const FormatErr = error{
    BufTooShort,
};

pub fn prettyUnsignedInt(buf: []u8, v: u64) !void {
    var b: [1000]u8 = std.mem.zeroes([1000]u8);
    var rv: [1000]u8 = std.mem.zeroes([1000]u8);
    const a = try std.fmt.bufPrint(&b, "{d}", .{v});
    var i: usize = 0;
    var a_i: usize = 0;
    var rv_len: usize = a.len + @divFloor(a.len, 3);
    if (@mod(a.len, 3) == 0) rv_len -= 1;
    while (i < rv_len) : (i += 1) {
        rv[rv_len - (i + 1)] = a[a.len - (a_i + 1)];
        a_i += 1;
        if (i + 1 < rv_len and @mod(a_i, 3) == 0) {
            i += 1;
            rv[rv_len - (i + 1)] = ',';
        }
    }
    @memcpy(buf[0..rv_len], rv[0..rv_len]);
    if (a.len > buf.len) return FormatErr.BufTooShort;
}

test prettyUnsignedInt {
    var buf: [100:0]u8 = std.mem.zeroes([100:0]u8);
    var v: u64 = 1_000;
    try prettyUnsignedInt(&buf, v);
    var actual: []u8 = std.mem.sliceTo(&buf, 0);
    try std.testing.expect(std.mem.eql(u8, "1,000", actual));
    buf = std.mem.zeroes([100:0]u8);
    v = 9_328_755;
    try prettyUnsignedInt(&buf, v);
    actual = std.mem.sliceTo(&buf, 0);
    try std.testing.expect(std.mem.eql(u8, "9,328,755", actual));
    buf = std.mem.zeroes([100:0]u8);
    v = 328_755;
    try prettyUnsignedInt(&buf, v);
    actual = std.mem.sliceTo(&buf, 0);
    std.testing.expect(std.mem.eql(u8, "328,755", actual)) catch |e| {
        std.debug.print("expected: '{s}' output: '{s}'\n", .{ "328,755", actual });
        return e;
    };
}

const std = @import("std");
