x: i32,
z: i32,
mutex: std.Thread.Mutex = .{},

const Column = @This();

pub const ColumnErr = error{
    NotFound,
};

const max_columns: usize = 124;
var columns: [max_columns]Column = undefined;
var num_columns: usize = 0;

fn indexOf(x: i32, z: i32, grow: bool) !usize {
    var i: usize = 0;
    while (i < num_columns) : (i += 1) {
        const c = columns[i];
        if (c.x == x and c.z == z) return i;
    }
    // Should not look for something new if not growing.
    if (!grow) return ColumnErr.NotFound;
    i += 1;
    std.debug.assert(i < max_columns);
    columns[i] = .{ .x = x, .z = z };
    num_columns = i;
    return i;
}

pub fn prime(x: i32, z: i32) void {
    _ = indexOf(x, z, true) catch unreachable;
}

pub fn lock(x: i32, z: i32) !usize {
    const i: usize = try indexOf(x, z, false);
    columns[i].mutex.lock();
    return i;
}

pub fn unlock(i: usize) void {
    std.debug.assert(i < max_columns);
    columns[i].mutex.unlock();
}

const std = @import("std");
