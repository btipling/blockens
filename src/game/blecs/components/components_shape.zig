const ecs = @import("zflecs");
const gl = @import("zopengl");
const zm = @import("zmath");
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");

pub const Plane = struct {
    color: ?math.vecs.Vflx4 = null,
    translate: ?math.vecs.Vflx3 = null,
    scale: ?math.vecs.Vflx3 = null,
    rotation: ?math.vecs.Vflx4 = null,
};

// Tags
pub const NeedsSetup = struct {};

pub fn init() void {
    ecs.COMPONENT(game.state.world, Plane);
    ecs.TAG(game.state.world, NeedsSetup);
}
