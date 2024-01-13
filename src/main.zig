const std = @import("std");
const game = @import("game/game.zig");

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();

    // // for sqlite, which recommends using an arena allocator
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();

    // var g = try game.Game.init(gpa.allocator(), arena.allocator());
    // defer g.deinit();
    // return g.run();
    std.debug.print("hello world\n", .{});
}
