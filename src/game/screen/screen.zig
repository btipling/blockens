const blecs = @import("../blecs/blecs.zig");
const game = @import("../game.zig");

pub const character = @import("character.zig");
pub const texture_gen = @import("texture_gen.zig");
pub const world = @import("world.zig");

pub fn showSettingsScreen() void {
    const screen: *blecs.components.screen.Screen = blecs.ecs.get_mut(
        game.state.world,
        game.state.entities.screen,
        blecs.components.screen.Screen,
    ) orelse unreachable;
    blecs.helpers.delete_children(game.state.world, game.state.entities.screen);
    screen.current = blecs.helpers.new_child(game.state.world, game.state.entities.screen);
    blecs.ecs.add(game.state.world, screen.current, blecs.components.screen.Settings);
    blecs.ecs.remove(game.state.world, game.state.entities.ui, blecs.components.ui.GameInfo);
    const menu: *blecs.components.ui.Menu = blecs.ecs.get_mut(
        game.state.world,
        game.state.entities.menu,
        blecs.components.ui.Menu,
    ) orelse unreachable;
    menu.visible = true;
}

pub fn showGameScreen() void {
    const screen: *blecs.components.screen.Screen = blecs.ecs.get_mut(
        game.state.world,
        game.state.entities.screen,
        blecs.components.screen.Screen,
    ) orelse unreachable;
    blecs.helpers.delete_children(game.state.world, game.state.entities.screen);
    screen.current = blecs.helpers.new_child(game.state.world, game.state.entities.screen);
    blecs.ecs.add(game.state.world, screen.current, blecs.components.screen.Game);
    blecs.ecs.add(game.state.world, game.state.entities.ui, blecs.components.ui.GameInfo);
    const menu: *blecs.components.ui.Menu = blecs.ecs.get_mut(
        game.state.world,
        game.state.entities.menu,
        blecs.components.ui.Menu,
    ) orelse unreachable;
    menu.visible = false;
}
