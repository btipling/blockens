const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const zm = @import("zmath");
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");
const config = @import("../../config.zig");
const components = @import("../components/components.zig");
const helpers = @import("../helpers.zig");

pub fn init() void {
    game.state.entities.ui = ecs.new_entity(game.state.world, "UI");
    ecs.add(game.state.world, game.state.entities.ui, components.ui.UI);
    ecs.add(game.state.world, game.state.entities.ui, components.ui.GameInfo);
}
