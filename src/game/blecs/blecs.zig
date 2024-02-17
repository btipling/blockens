pub const ecs = @import("zflecs");
const systems = @import("systems/systems.zig");
const entities = @import("entities/entities.zig");
pub const components = @import("components/components.zig");
pub const tags = @import("tags.zig");
pub const game = @import("../game.zig");

pub fn init() void {
    game.state.world = ecs.init();
    components.init();
    tags.init();
    systems.init();
    entities.init();
}
