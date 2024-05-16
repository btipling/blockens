const system_name = "UIDisplaySettingsSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.DisplaySettings) };
    desc.run = if (config.use_tracy) runWithTrace else run;
    return desc;
}

fn runWithTrace(it: *ecs.iter_t) callconv(.C) void {
    ztracy.Message(system_name);
    const tracy_zone = ztracy.ZoneNC(@src(), system_name, 0xff_00_ff_f0);
    defer tracy_zone.End();
    return run(it);
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = game.state.ui.imguiX(660);
            const yPos: f32 = game.state.ui.imguiY(300);
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = game.state.ui.imguiWidth(600),
                .h = game.state.ui.imguiHeight(300),
                .cond = .always,
            });
            if (zgui.begin("Display Settings", .{
                .flags = zgui.WindowFlags.no_decoration,
            })) {
                const btn_dms: [2]f32 = game.state.ui.imguiButtonDims();
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

                const size_option = struct {
                    w: i32,
                    h: i32,
                };
                var num_options: usize = 0;
                var options: [100]size_option = undefined;

                var selected_index: isize = -1;
                var preview_value: []const u8 = "Not selected";
                {
                    var i: usize = 0;
                    while (i < all.len) : (i += 1) {
                        outer: {
                            const vm = all[i];
                            const w: i32 = @intCast(vm.width);
                            const h: i32 = @intCast(vm.height);
                            var ii: usize = 0;

                            while (ii < num_options) : (ii += 1) {
                                const no = options[ii];
                                if (no.w == w and no.h == h) {
                                    break :outer;
                                }
                            }
                            options[num_options] = .{ .w = w, .h = h };
                            num_options += 1;

                            if (game.state.ui.display_settings_width != w or game.state.ui.display_settings_height != h) continue;

                            var pb_buf: [100]u8 = [_]u8{0} ** 100;
                            preview_value = std.fmt.bufPrint(
                                &pb_buf,
                                "{d} x {d}",
                                .{ h, w },
                            ) catch @panic("invalid buffer size");
                            selected_index = @intCast(num_options);
                        }
                    }
                }

                zgui.setNextItemWidth(game.state.ui.imguiWidth(250));
                cw = zgui.beginPopupContextWindow();
                combo = zgui.beginCombo("##listbox", .{
                    .preview_value = @ptrCast(preview_value),
                });
                if (combo) {
                    var i: usize = 0;
                    while (i < num_options) : (i += 1) {
                        const o = options[i];
                        var sn_buf: [100]u8 = [_]u8{0} ** 100;
                        const selectable_name = std.fmt.bufPrint(
                            &sn_buf,
                            "{d} x {d}",
                            .{ o.h, o.w },
                        ) catch @panic("invalid buffer size");

                        if (zgui.selectable(@ptrCast(selectable_name), .{
                            .selected = i == @as(usize, @intCast(selected_index)),
                        })) {
                            std.debug.print("Selected: {d}, {d}\n", .{ o.w, o.h });
                            game.state.ui.display_settings_width = @intCast(o.w);
                            game.state.ui.display_settings_height = @intCast(o.h);
                        }
                    }
                }
                if (cw) zgui.endPopup();
                if (combo) zgui.endCombo();
                centerNext(ww);
                if (zgui.button("Save", .{
                    .w = btn_dms[0],
                    .h = btn_dms[1],
                })) {
                    game.state.db.updateDisplaySettings(
                        game.state.ui.display_settings_fullscreen,
                        game.state.ui.display_settings_maximized,
                        game.state.ui.display_settings_decorated,
                        game.state.ui.display_settings_width,
                        game.state.ui.display_settings_height,
                    ) catch @panic("DB Err");
                    screen_helpers.showTitleScreen();
                }

                centerNext(ww);
                if (zgui.button("Cancel", .{
                    .w = btn_dms[0],
                    .h = btn_dms[1],
                })) {
                    screen_helpers.showTitleScreen();
                }
            }
            zgui.end();
        }
    }
}

fn centerNext(ww: f32) void {
    zgui.newLine();
    zgui.sameLine(.{
        .offset_from_start_x = ww / 2 - game.state.ui.imguiWidth(125),
        .spacing = game.state.ui.imguiWidth(10),
    });
}

const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../components/components.zig");
const screen_helpers = @import("../screen_helpers.zig");
const game = @import("../../../game.zig");
