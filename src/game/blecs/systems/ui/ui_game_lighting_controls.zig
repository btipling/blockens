const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const screen_helpers = @import("../screen_helpers.zig");
const chunk = @import("../../../chunk.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UILightingControlsSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.LightingControls) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            zgui.setNextItemWidth(-1);
            if (zgui.begin("Lighting Controls", .{
                .flags = .{
                    .menu_bar = true,
                },
            })) {
                if (zgui.beginMenuBar()) {
                    if (zgui.menuItem("Close", .{})) {
                        screen_helpers.toggleLightingControls();
                    }
                    zgui.endMenuBar();
                }
                showLightingControls() catch @panic("nope");
            }
            zgui.end();
        }
    }
}

fn showLightingControls() !void {
    if (zgui.inputFloat("lighting input", .{
        .v = &game.state.gfx.ambient_lighting,
    })) {
        entities.screen.initDemoChunkCamera();
    }
    if (zgui.sliderFloat("lighting slider", .{
        .v = &game.state.gfx.ambient_lighting,
        .min = 0,
        .max = 1,
    })) {
        game.state.gfx.update_lighting();
    }
    if (zgui.button("Run lighting", .{
        .w = 600,
        .h = 100,
    })) {
        runLighting();
    }
}

fn runLighting() void {
    _ = game.state.jobs.lighting(0, 0);
}
