const ecs = @import("zflecs");
const game = @import("../../../game.zig");

pub const TextureGen = struct {};

pub fn init() void {
    ecs.TAG(game.state.world, TextureGen);
}
