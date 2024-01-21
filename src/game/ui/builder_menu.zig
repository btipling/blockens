const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const config = @import("../config.zig");
const shape = @import("../shape/shape.zig");
const state = @import("../state.zig");
const data = @import("../data/data.zig");

pub const BuilderMenu = struct {
    appState: *state.State,

    pub fn init(appState: *state.State) !BuilderMenu {
        return BuilderMenu{
            .appState = appState,
        };
    }

    pub fn draw(self: *BuilderMenu, window: *glfw.Window) !void {
        window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.normal);
        if (self.appState.demoView.showUILog) {
            var show = true;
            zgui.showDemoWindow(&show);
        }
        if (self.appState.demoView.showUIMetrics) {
            var show = true;
            zgui.showMetricsWindow(&show);
        }
        if (zgui.beginMainMenuBar()) {
            zgui.pushStyleVar2f(.{ .idx = .item_spacing, .v = [2]f32{ 20.0, 20.0 } });
            if (zgui.menuItem("game", .{})) {
                window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);
                try self.appState.setGameView();
            }
            if (zgui.menuItem("textures", .{})) {
                try self.appState.setTextureGeneratorView();
            }
            if (zgui.menuItem("blocks", .{})) {
                try self.appState.setBlockEditorView();
            }
            if (zgui.menuItem("worlds", .{})) {
                try self.appState.setWorldEditorView();
            }
            if (zgui.menuItem("chunks", .{})) {
                try self.appState.setChunkGeneratorView();
            }
            const ww = zgui.getWindowWidth();
            zgui.sameLine(.{ .offset_from_start_x = ww - 150.0 });
            if (zgui.menuItem("exit", .{})) {
                try self.appState.exitGame();
            }
            zgui.popStyleVar(.{ .count = 1 });
            zgui.endMainMenuBar();
        }
    }
};
