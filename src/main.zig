const game = @import("game/game.zig");

pub fn main() !void {
    var bg = try game.Game.init();
    defer bg.deinit();

    var g = &bg;
    try g.run();
}
