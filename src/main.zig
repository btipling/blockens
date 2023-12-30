const game = @import("game/game.zig");

pub fn main() !void {
    const bg = try game.Game.init();
    defer bg.deinit();

    try bg.run();
}
