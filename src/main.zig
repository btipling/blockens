const std = @import("std");
const temp = @import("temp/app.zig");

pub fn main() !void {
    std.debug.print("hello world\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // for sqlite, which recommends using an arena allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var g = try temp.App.init(gpa.allocator(), arena.allocator());
    defer g.deinit();
    return g.run();
}
