const std = @import("std");
const ztracy = @import("ztracy");
const game = @import("game/game.zig");
const config = @import("config");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var g: game.Game = undefined;
    if (config.use_tracy) {
        const tracy_zone = ztracy.ZoneNC(@src(), "Blockens", 0x00_ff_00_00);
        defer tracy_zone.End();
        var tracy_allocator = ztracy.TracyAllocator.init(gpa.allocator());
        g = try game.Game.init(tracy_allocator.allocator());
    } else {
        g = try game.Game.init(gpa.allocator());
    }

    defer g.deinit();
    return g.run();
}
