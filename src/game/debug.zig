const std = @import("std");
const zm = @import("zmath");

pub fn printM4(m: zm.Mat) void {
    const r = zm.matToArr(m);
    std.debug.print("\n\n**** Debug zm.mat: ****\n", .{});
    for (0..4) |i| {
        std.debug.print("  [{d}, {d}, {d}, {d}]\n", .{
            r[(i * 4) + 0],
            r[(i * 4) + 1],
            r[(i * 4) + 2],
            r[(i * 4) + 3],
        });
    }
    std.debug.print("**** ~ end ~ ****\n\n", .{});
}
