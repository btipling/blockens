const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const config = @import("../config.zig");
const shape = @import("../shape/shape.zig");
const state = @import("../state/state.zig");
const chunk = @import("../chunk.zig");
const data = @import("../data/data.zig");
const script = @import("../script/script.zig");
const menus = @import("menus.zig");

const maxWorldSizeName = 20;

pub const CharacterDesigner = struct {
    appState: *state.State,
    codeFont: zgui.Font,
    bm: menus.BuilderMenu,

    pub fn init(
        appState: *state.State,
        codeFont: zgui.Font,
        bm: menus.BuilderMenu,
    ) !CharacterDesigner {
        const cd = CharacterDesigner{
            .appState = appState,
            .codeFont = codeFont,
            .bm = bm,
        };
        return cd;
    }

    pub fn deinit(self: *CharacterDesigner) void {
        _ = self;
    }

    pub fn draw(self: *CharacterDesigner, window: *glfw.Window) !void {
        const xPos: f32 = 2200.0;
        const yPos: f32 = 50.0;
        zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
        zgui.setNextWindowSize(.{
            .w = 1600,
            .h = 2000,
        });
        zgui.setNextItemWidth(-1);
        if (zgui.begin("Character Designer", .{
            .flags = .{
                .no_title_bar = false,
                .no_resize = false,
                .no_scrollbar = false,
                .no_collapse = false,
            },
        })) {
            try self.bm.draw(window);
        }
        zgui.end();
    }
};
