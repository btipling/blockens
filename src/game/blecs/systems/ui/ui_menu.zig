const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");

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
        for (0..it.count()) |i| {
            const ms: []components.ui.Menu = ecs.field(it, components.ui.Menu, 1) orelse return;
            const menu = ms[i];
            if (!menu.visible) continue;

            if (zgui.beginMainMenuBar()) {
                zgui.pushStyleVar2f(.{ .idx = .item_spacing, .v = [2]f32{ 20.0, 20.0 } });
                if (zgui.menuItem("game", .{})) {
                    std.debug.print("picked game menu item\n", .{});
                }
                if (zgui.menuItem("settings", .{})) {
                    std.debug.print("picked settings menu item\n", .{});
                }
                zgui.popStyleVar(.{ .count = 1 });
                zgui.endMainMenuBar();
            }
        }
    }
}
