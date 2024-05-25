pub fn init() void {
    game.state.entities.ui = ecs.new_entity(game.state.world, "UI");
    _ = ecs.set(game.state.world, game.state.entities.ui, components.ui.UI, .{ .dialog_count = 0 });
    ecs.add(game.state.world, game.state.entities.ui, components.ui.GameInfo);
}

const ecs = @import("zflecs");
const game = @import("../../game.zig");
const components = @import("../components/components.zig");
