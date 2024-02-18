const std = @import("std");
const game = @import("game/game.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var g = try game.Game.init(gpa.allocator());
    defer g.deinit();
    return g.run();
}
