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
            const xPos: f32 = game.state.ui.imguiX(660);
            const yPos: f32 = game.state.ui.imguiY(300);
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = game.state.ui.imguiWidth(600),
                .h = game.state.ui.imguiHeight(200),
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
                zgui.newLine();
                zgui.text("Terrain generation: {d:.2}%", .{game.state.ui.load_percentage_world_gen * 100});
                zgui.text("Lighting initial: {d:.2}%", .{game.state.ui.load_percentage_lighting_initial * 100});
                zgui.text("Lighting cross chunk: {d:.2}%", .{game.state.ui.load_percentage_lighting_cross_chunk * 100});
                zgui.text("Loading chunks: {d:.2}%", .{game.state.ui.load_percentage_load_chunks * 100});
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
