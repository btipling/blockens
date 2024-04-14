pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UILoadingScreenSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.LoadingScreen) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = 1500.0;
            const yPos: f32 = 800.0;
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = 800,
                .h = 500,
            });
            if (zgui.begin("#LoadingScreen", .{
                .flags = zgui.WindowFlags.no_decoration,
            })) {
                zgui.text("Loading...", .{});
                const ww = zgui.getWindowWidth();
                zgui.newLine();
                zgui.newLine();

                centerNext(ww);
                zgui.text("Starting world.", .{});
            }
            zgui.end();
        }
    }
}

fn centerNext(ww: f32) void {
    zgui.newLine();
    zgui.sameLine(.{
        .offset_from_start_x = ww / 2 - 250,
        .spacing = 20,
    });
}

const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
