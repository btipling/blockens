const blecs = @import("../blecs/blecs.zig");
const game = @import("../game.zig");

pub const character = @import("character.zig");
pub const texture_gen = @import("texture_gen.zig");
pub const world = @import("world.zig");

pub fn showBlockTextureGen() void {
    showSettingsScreen();
    const screen: *const blecs.components.screen.Screen = blecs.ecs.get(
        game.state.world,
        game.state.entities.screen,
        blecs.components.screen.Screen,
    ) orelse unreachable;
    blecs.ecs.add(game.state.world, screen.current, blecs.components.screen.texture_gen.TextureGen);
}

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
    blecs.ecs.add(game.state.world, game.state.entities.ui, blecs.components.ui.Menu);
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
    blecs.ecs.remove(game.state.world, game.state.entities.ui, blecs.components.ui.Menu);
}

pub fn toggleCameraOptions() void {}
pub fn toggleDemoOptions() void {}
