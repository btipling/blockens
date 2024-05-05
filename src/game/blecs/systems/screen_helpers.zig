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

pub fn showTerrainEditor() void {
    showSettingsScreen(blecs.components.screen.TerrainEditor);
}

pub fn showWorldEditor() void {
    showSettingsScreen(blecs.components.screen.WorldEditor);
}

pub fn showTitleScreen() void {
    showSettingsScreen(blecs.components.screen.TitleScreen);
}

pub fn showSettingUpScreen() void {
    showSettingsScreen(blecs.components.screen.SettingUpScreen);
}

pub fn showLoadingScreen() void {
    showSettingsScreen(blecs.components.screen.LoadingScreen);
}

pub fn showDisplaySettingsScreen() void {
    showSettingsScreen(blecs.components.screen.DisplaySettings);
}

pub fn toggleScreens() void {
    const world = game.state.world;
    const screen: *const blecs.components.screen.Screen = blecs.ecs.get(
        world,
        game.state.entities.screen,
        blecs.components.screen.Screen,
    ) orelse @panic("no screen");
    if (blecs.ecs.has_id(world, screen.current, blecs.ecs.id(blecs.components.screen.Game))) {
        return showTitleScreen();
    }
    if (blecs.ecs.has_id(game.state.world, screen.current, blecs.ecs.id(blecs.components.screen.TitleScreen))) {
        return showGameScreen();
    }
    return showTitleScreen();
}

pub fn showSettingsScreen(comptime T: type) void {
    const screen: *blecs.components.screen.Screen = blecs.ecs.get_mut(
        game.state.world,
        game.state.entities.screen,
        blecs.components.screen.Screen,
    ) orelse @panic("no screen");
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
    ) orelse @panic("no screen");
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

pub fn toggleDemoCharacterOptions() void {
    toggleUI(blecs.components.ui.DemoCharacter);
}

pub fn toggleGameChunksInfo() void {
    toggleUI(blecs.components.ui.GameChunksInfo);
}

pub fn toggleGameMobInfo() void {
    toggleUI(blecs.components.ui.GameMobInfo);
}

pub fn toggleLightingControls() void {
    toggleUI(blecs.components.ui.LightingControls);
}

fn toggleUI(comptime T: type) void {
    const world = game.state.world;
    const entity = game.state.entities.ui;
    const ui: *blecs.components.ui.UI = blecs.ecs.get_mut(world, entity, blecs.components.ui.UI) orelse return;
    if (blecs.ecs.has_id(world, entity, blecs.ecs.id(T))) {
        blecs.ecs.remove(world, entity, T);
        ui.dialog_count -= 1;
        if (ui.dialog_count < 0) std.debug.panic("invalid ui dialog count: {d}\n", .{ui.dialog_count});
        return;
    }
    blecs.ecs.add(world, entity, T);
    ui.dialog_count += 1;
}

pub fn toggleWireframe(entity: blecs.ecs.entity_t) void {
    if (blecs.ecs.has_id(game.state.world, entity, blecs.ecs.id(blecs.components.gfx.Wireframe))) {
        blecs.ecs.remove(game.state.world, entity, blecs.components.gfx.Wireframe);
        return;
    }
    blecs.ecs.add(game.state.world, entity, blecs.components.gfx.Wireframe);
}

const std = @import("std");
const blecs = @import("../blecs.zig");
const game = @import("../../game.zig");
