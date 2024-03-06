const ecs = @import("zflecs");
const gl = @import("zopengl").bindings;
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");
pub const shape = @import("components_shape.zig");
pub const gfx = @import("components_gfx.zig");
pub const ui = @import("components_ui.zig");
pub const block = @import("components_block.zig");
pub const screen = @import("components_screen.zig");
pub const mob = @import("components_mob.zig");

pub const Time = struct {
    startTime: i64 = 0,
    currentTime: i64 = 0,
};

pub const Sky = struct {
    sun: SunState = .rising,
    lastSet: i64 = 0,
    pub const SunState = enum {
        rising,
        setting,
    };
};

pub const Debug = struct {};

pub fn init() void {
    ecs.COMPONENT(game.state.world, Time);
    ecs.COMPONENT(game.state.world, Sky);
    ecs.TAG(game.state.world, Debug);
    shape.init();
    gfx.init();
    ui.init();
    screen.init();
    block.init();
    mob.init();
}
