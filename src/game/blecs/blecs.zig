pub const ecs = @import("zflecs");
const systems = @import("systems/systems.zig");
pub const entities = @import("entities/entities.zig");
pub const components = @import("components/components.zig");
pub const tags = @import("tags.zig");
pub const game = @import("../game.zig");
pub const helpers = @import("helpers.zig");

pub fn init() void {
    game.state.world = ecs.init();
    ecs.set_target_fps(game.state.world, 120);
    components.init();
    tags.init();
    systems.init();
    entities.init();
    systems.helpers.showTitleScreen();
}
