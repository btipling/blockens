const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const screen_helpers = @import("../../../screen/screen.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UISettingsCameraSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.SettingsCamera) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            zgui.setNextWindowSize(.{
                .w = 500,
                .h = 500,
            });
            zgui.setNextItemWidth(-1);
            if (zgui.begin("Settings Camera", .{
                .flags = .{
                    .no_title_bar = false,
                    .no_resize = false,
                    .no_scrollbar = true,
                    .no_collapse = false,
                },
            })) {
                zgui.text("settings camera", .{});
            }
            zgui.end();
        }
    }
}
