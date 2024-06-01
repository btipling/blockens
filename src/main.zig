pub fn main() !void {
    if (builtin.mode == .Debug) return runDebug();
    var g: game.Game = try game.Game.init(std.heap.c_allocator);
    defer g.deinit();
    return g.run();
}

pub fn runDebug() !void {
    var g: game.Game = undefined;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    if (config.use_tracy) {
        const ztracy = @import("ztracy");
        const tracy_zone = ztracy.ZoneNC(@src(), "Blockens Init", 0x00_ff_00_00);
        defer tracy_zone.End();
        // var tracy_allocator = ztracy.TracyAllocator.init(gpa.allocator());
        // g = try game.Game.init(tracy_allocator.allocator());
        g = try game.Game.init(gpa.allocator());
    } else {
        g = try game.Game.init(gpa.allocator());
    }
    defer g.deinit();
    return g.run();
}

const std = @import("std");
const config = @import("config");
const builtin = @import("builtin");
const game = @import("game/game.zig");
