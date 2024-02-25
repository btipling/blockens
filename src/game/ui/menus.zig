const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl").bindings;
const glfw = @import("zglfw");
const config = @import("../config.zig");
const shape = @import("../shape/shape.zig");
const state = @import("../state/state.zig");
const data = @import("../data/data.zig");
const script = @import("../script/script.zig");

pub const BuilderMenu = struct {
    appState: *state.State,

    pub fn init(appState: *state.State) !BuilderMenu {
        return BuilderMenu{
            .appState = appState,
        };
    }

    pub fn draw(self: *BuilderMenu, window: *glfw.Window) !void {
        window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.normal);
        if (self.appState.demoScreen.showUILog) {
            var show = true;
            zgui.showDemoWindow(&show);
        }
        if (self.appState.demoScreen.showUIMetrics) {
            var show = true;
            zgui.showMetricsWindow(&show);
        }
        if (zgui.beginMainMenuBar()) {
            zgui.pushStyleVar2f(.{ .idx = .item_spacing, .v = [2]f32{ 20.0, 20.0 } });
            if (zgui.menuItem("game", .{})) {
                window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);
                try self.appState.setGameScreen();
            }
            if (zgui.menuItem("textures", .{})) {
                try self.appState.setTextureGeneratorScreen();
            }
            if (zgui.menuItem("blocks", .{})) {
                try self.appState.setBlockEditorScreen();
            }
            if (zgui.menuItem("worlds", .{})) {
                try self.appState.setWorldEditorScreen();
            }
            if (zgui.menuItem("chunks", .{})) {
                try self.appState.setChunkGeneratorScreen();
            }
            if (zgui.menuItem("characters", .{})) {
                try self.appState.setCharacterDesignerScreen();
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

const ScriptOptionsParams = struct {
    w: f32 = 500.0,
    h: f32 = 900.0,
};

pub fn scriptOptionsListBox(scriptOptions: std.ArrayList(data.chunkScriptOption), params: ScriptOptionsParams) ?i32 {
    var rv: ?i32 = null;
    if (zgui.beginListBox("##chunk_script_options", .{
        .w = params.w,
        .h = params.h,
    })) {
        zgui.pushStyleColor4f(.{ .idx = .header_hovered, .c = .{ 1.0, 1.0, 1.0, 0.25 } });
        for (scriptOptions.items) |scriptOption| {
            var buffer: [script.maxLuaScriptNameSize + 10]u8 = undefined;

            var sn = scriptOption.name;
            var st: usize = 0;
            for (0..scriptOption.name.len) |i| {
                if (scriptOption.name[i] == 0) {
                    st = i;
                    break;
                }
            }
            if (st == 0) {
                break;
            }
            var name = std.fmt.bufPrintZ(&buffer, "  {d}: {s}", .{ scriptOption.id, sn[0..st :0] }) catch {
                std.debug.print("unable to write selectable name.\n", .{});
                continue;
            };
            _ = &name;
            var dl = zgui.getWindowDrawList();
            const pmin = zgui.getCursorScreenPos();
            const pmax = [2]f32{ pmin[0] + 35.0, pmin[1] + 30.0 };
            const col = zgui.colorConvertFloat4ToU32(.{ scriptOption.color[0], scriptOption.color[1], scriptOption.color[2], 1.0 });
            dl.addRectFilled(.{ .pmin = pmin, .pmax = pmax, .col = col });

            if (zgui.selectable(name, .{ .h = 60 })) {
                rv = scriptOption.id;
            }
        }
        zgui.popStyleColor(.{ .count = 1 });
        zgui.endListBox();
    }
    return rv;
}
