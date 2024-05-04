pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UISettingUpScreenSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.SettingUpScreen) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = game.state.ui.imguiX(660);
            const yPos: f32 = game.state.ui.imguiY(300);
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = game.state.ui.imguiWidth(600),
                .h = game.state.ui.imguiHeight(200),
            });
            if (zgui.begin("#SettingUpScreen", .{
                .flags = zgui.WindowFlags.no_decoration,
            })) {
                zgui.text("Starting...", .{});
                const ww = zgui.getWindowWidth();
                zgui.newLine();
                zgui.newLine();

                centerNext(ww);
                zgui.text("Setting up...", .{});
            }
            zgui.end();
        }
    }
}

fn centerNext(ww: f32) void {
    zgui.newLine();
    zgui.sameLine(.{
        .offset_from_start_x = ww / 2 - game.state.ui.imguiWidth(100),
        .spacing = game.state.ui.imguiWidth(10),
    });
}

const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
