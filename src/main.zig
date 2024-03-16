const std = @import("std");
const ztracy = @import("ztracy");
const game = @import("game/game.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // --- Uncomment below to get tracy traces! ---
    // const tracy_zone = ztracy.ZoneNC(@src(), "Blockens", 0x00_ff_00_00);
    // defer tracy_zone.End();
    // var tracy_allocator = ztracy.TracyAllocator.init(gpa.allocator());
    // var allocator = tracy_allocator.allocator();
    // var g = try game.Game.init(tracy_allocator.allocator());

    var g = try game.Game.init(gpa.allocator());
    defer g.deinit();
    return g.run();
}
