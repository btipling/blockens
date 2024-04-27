pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UIDisplaySettingsSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.DisplaySettings) };
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
            if (zgui.begin("DisplaymSettings", .{
                .flags = zgui.WindowFlags.no_decoration,
            })) {
                const ww = zgui.getWindowWidth();
                zgui.text("Changes require a restart.", .{});

                zgui.newLine();

                centerNext(ww);
                if (zgui.checkbox("Fullscreen", .{
                    .v = &game.state.ui.display_settings_fullscreen,
                })) {}
                centerNext(ww);
                if (zgui.checkbox("Maximized", .{
                    .v = &game.state.ui.display_settings_maximized,
                })) {}
                centerNext(ww);
                if (zgui.checkbox("Decorated", .{
                    .v = &game.state.ui.display_settings_decorated,
                })) {}

                centerNext(ww);
                var combo: bool = false;
                var cw: bool = false;
                const m = glfw.Monitor.getPrimary() orelse @panic("no primary monitor");
                const all = m.getVideoModes() catch @panic("no video modes for monitor");

                zgui.setNextItemWidth(game.state.ui.imguiWidth(250));
                combo = zgui.beginCombo("##listbox", .{
                    .preview_value = "lol",
                });
                cw = zgui.beginPopupContextWindow();

                if (combo) {
                    var i: usize = 0;
                    while (i < all.len) : (i += 1) {
                        const m_ = all[i];
                        const h = m_.height;
                        const w = m_.width;
                        var buf: [100]u8 = [_]u8{0} ** 100;
                        const selectable_name = std.fmt.bufPrint(
                            &buf,
                            "{d} x {d}",
                            .{ w, h },
                        ) catch unreachable;

                        if (zgui.selectable(@ptrCast(selectable_name), .{ .selected = false })) {
                            std.debug.print("Selected: {d}, {d}\n", .{ w, h });
                        }
                    }
                }
                if (cw) zgui.endPopup();
                if (combo) zgui.endCombo();
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
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
