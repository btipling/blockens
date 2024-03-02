const blecs = @import("../blecs/blecs.zig");
const game = @import("../game.zig");

pub const character = @import("character.zig");
pub const texture_gen = @import("texture_gen.zig");
pub const world = @import("world.zig");

pub fn showBlockTextureGen() void {
    showSettingsScreen(blecs.components.screen.TextureGen);
}

pub fn showBlockEditor() void {
    showSettingsScreen(blecs.components.screen.BlockEditor);
}

pub fn showChunkEditor() void {
    showSettingsScreen(blecs.components.screen.ChunkEditor);
}

pub fn showCharacterEditor() void {
    showSettingsScreen(blecs.components.screen.CharacterEditor);
}

pub fn showWorldEditor() void {
    showSettingsScreen(blecs.components.screen.WorldEditor);
}

pub fn showSettingsScreen(comptime T: type) void {
    const screen: *blecs.components.screen.Screen = blecs.ecs.get_mut(
        game.state.world,
        game.state.entities.screen,
        blecs.components.screen.Screen,
    ) orelse unreachable;
    // reset any previous demo objects added to the settings screen
    blecs.entities.screen.clearDemoObjects();
    // clear out the screens previous child, world or setting, this doesn't clear world objects, they are not cleared
    blecs.helpers.delete_children(game.state.world, game.state.entities.screen);
    // make a new current screen of the settings type
    screen.current = blecs.helpers.new_child(game.state.world, game.state.entities.screen);
    blecs.ecs.add(game.state.world, screen.current, blecs.components.screen.Settings);
    // Remove the game info UI
    blecs.ecs.remove(game.state.world, game.state.entities.ui, blecs.components.ui.GameInfo);
    // Add the menu UI, all settings have this
    blecs.ecs.add(game.state.world, game.state.entities.ui, blecs.components.ui.Menu);
    // Remove any post perspective setting from the transforms sent for settings, as they may differ for different setting screens
    blecs.ecs.remove(game.state.world, game.state.entities.settings_camera, blecs.components.screen.PostPerspective);
    // Add the specific setting screen
    blecs.ecs.add(game.state.world, screen.current, T);
}

pub fn showGameScreen() void {
    const screen: *blecs.components.screen.Screen = blecs.ecs.get_mut(
        game.state.world,
        game.state.entities.screen,
        blecs.components.screen.Screen,
    ) orelse unreachable;
    // Same as for settings but we don't clear anything, just change back to the game
    blecs.helpers.delete_children(game.state.world, game.state.entities.screen);
    screen.current = blecs.helpers.new_child(game.state.world, game.state.entities.screen);
    blecs.ecs.add(game.state.world, screen.current, blecs.components.screen.Game);
    blecs.ecs.add(game.state.world, game.state.entities.ui, blecs.components.ui.GameInfo);
    blecs.ecs.remove(game.state.world, game.state.entities.ui, blecs.components.ui.Menu);
}

pub fn toggleCameraOptions() void {
    toggleUI(blecs.components.ui.SettingsCamera);
}

pub fn toggleDemoCubeOptions() void {
    toggleUI(blecs.components.ui.DemoCube);
}

pub fn toggleDemoChunkOptions() void {
    toggleUI(blecs.components.ui.DemoChunk);
}

fn toggleUI(comptime T: type) void {
    if (blecs.ecs.has_id(game.state.world, game.state.entities.ui, blecs.ecs.id(T))) {
        blecs.ecs.remove(game.state.world, game.state.entities.ui, T);
        return;
    }
    blecs.ecs.add(game.state.world, game.state.entities.ui, T);
}
