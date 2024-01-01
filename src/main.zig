const std = @import("std");
const game = @import("game/game.zig");

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // var g = game.Game.init(gpa.allocator());
    var g = try game.Game.init(arena.allocator());
    defer g.deinit();
    return g.run();
}
