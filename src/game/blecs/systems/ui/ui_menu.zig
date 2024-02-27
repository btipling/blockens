const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const gl = @import("zopengl").bindings;
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const screen_helpers = @import("../../../screen/screen.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UIMenuSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.Menu) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            if (zgui.beginMainMenuBar()) {
                zgui.pushStyleVar2f(.{ .idx = .item_spacing, .v = [2]f32{ 20.0, 20.0 } });
                if (zgui.beginMenu("Game", true)) {
                    if (zgui.menuItem("Play", .{})) {
                        screen_helpers.showGameScreen();
                    }
                    if (zgui.menuItem("Exit", .{})) {
                        game.state.quit = true;
                    }
                    zgui.endMenu();
                }
                if (zgui.beginMenu("Build Tools", true)) {
                    if (zgui.menuItem("World Editor", .{})) {
                        screen_helpers.showWorldEditor();
                    }
                    if (zgui.menuItem("Block Textures", .{})) {
                        screen_helpers.showBlockTextureGen();
                    }
                    if (zgui.menuItem("Block Editor", .{})) {
                        screen_helpers.showBlockEditor();
                    }
                    if (zgui.menuItem("Chunk Editor", .{})) {
                        screen_helpers.showChunkEditor();
                    }
                    if (zgui.menuItem("Character", .{})) {
                        screen_helpers.showCharacterEditor();
                    }
                    zgui.endMenu();
                }
                if (zgui.beginMenu("Settings UI", true)) {
                    if (zgui.menuItem("Toogle Camera Options", .{})) {
                        screen_helpers.toggleCameraOptions();
                    }
                    if (zgui.menuItem("Toggle Demo Cube Options", .{})) {
                        screen_helpers.toggleDemoOptions();
                    }
                    zgui.endMenu();
                }
                const ww = zgui.getWindowWidth();
                zgui.sameLine(.{ .offset_from_start_x = ww - 50.0 });
                if (zgui.menuItem("X", .{})) {
                    game.state.quit = true;
                }
                zgui.popStyleVar(.{ .count = 1 });
                zgui.endMainMenuBar();
            }
        }
    }
}
