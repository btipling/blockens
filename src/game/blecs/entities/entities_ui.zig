const ecs = @import("zflecs");
const game = @import("../../game.zig");
const components = @import("../components/components.zig");

pub fn init() void {
    game.state.entities.ui = ecs.new_entity(game.state.world, "UI");
    ecs.add(game.state.world, game.state.entities.ui, components.ui.UI);
    ecs.add(game.state.world, game.state.entities.ui, components.ui.GameInfo);
}
