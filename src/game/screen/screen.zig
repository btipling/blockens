const blecs = @import("../blecs/blecs.zig");
const game = @import("../game.zig");

pub const character = @import("character.zig");
pub const texture_gen = @import("texture_gen.zig");
pub const world = @import("world.zig");

pub fn showSettingsScreen(
    w: *blecs.ecs.world_t,
    screen: *blecs.components.screen.Screen,
    screenEntity: blecs.ecs.entity_t,
) void {
    blecs.helpers.delete_children(w, screenEntity);
    screen.current = blecs.helpers.new_child(w, screenEntity);
    blecs.ecs.add(game.state.world, screen.current, blecs.components.screen.Settings);
    const menu: *blecs.components.ui.Menu = blecs.ecs.get_mut(
        game.state.world,
        game.state.entities.menu,
        blecs.components.ui.Menu,
    ) orelse unreachable;
    menu.visible = true;
}

pub fn showGameScreen(
    w: *blecs.ecs.world_t,
    screen: *blecs.components.screen.Screen,
    screenEntity: blecs.ecs.entity_t,
) void {
    blecs.helpers.delete_children(w, screenEntity);
    screen.current = blecs.helpers.new_child(w, screenEntity);
    blecs.ecs.add(game.state.world, screen.current, blecs.components.screen.Game);
    const menu: *blecs.components.ui.Menu = blecs.ecs.get_mut(
        game.state.world,
        game.state.entities.menu,
        blecs.components.ui.Menu,
    ) orelse unreachable;
    menu.visible = false;
}
