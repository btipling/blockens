const system_name = "UITitleScreenSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.TitleScreen) };
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
    const btn_dms: [2]f32 = game.state.ui.imguiButtonDims();
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = game.state.ui.imguiX(660);
            const yPos: f32 = game.state.ui.imguiY(300);
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = game.state.ui.imguiWidth(600),
                .h = game.state.ui.imguiHeight(300),
            });
            if (zgui.begin("#TitleScreen", .{
                .flags = zgui.WindowFlags.no_decoration,
            })) {
                zgui.text("Blockens!", .{});
                const ww = zgui.getWindowWidth();
                zgui.newLine();
                zgui.newLine();

                centerNext(ww);
                if (helpers.worldChooser(.{
                    .world_id = game.state.ui.world_loaded_id,
                    .name = game.state.ui.world_loaded_name,
                })) |selected| {
                    loadWorld(selected.world_id, selected.name);
                }

                centerNext(ww);
                zgui.beginDisabled(.{ .disabled = game.state.ui.world_options.items.len == 0 });
                if (zgui.button("Play", .{
                    .w = btn_dms[0],
                    .h = btn_dms[1],
                })) {
                    const loadedGame = game.state.ui.world_chunk_table_data.count() > 0;
                    if (!loadedGame or game.state.ui.world_loaded_id == 0) {
                        screen_helpers.showLoadingScreen();
                        _ = game.state.jobs.loadChunks(game.state.ui.world_loaded_id, true);
                    } else {
                        screen_helpers.showGameScreen();
                    }
                }
                zgui.endDisabled();

                centerNext(ww);
                if (zgui.button("Create World", .{
                    .w = btn_dms[0],
                    .h = btn_dms[1],
                })) {
                    screen_helpers.showCreateWorldScreen();
                }

                centerNext(ww);
                if (zgui.button("Display Settings", .{
                    .w = btn_dms[0],
                    .h = btn_dms[1],
                })) {
                    screen_helpers.showDisplaySettingsScreen();
                }

                centerNext(ww);
                if (zgui.button("Exit", .{
                    .w = btn_dms[0],
                    .h = btn_dms[1],
                })) {
                    game.state.quit = true;
                }
            }
            zgui.end();
        }
    }
}

fn loadWorld(world_id: i32, name: [ui.max_world_name:0]u8) void {
    std.debug.print("selecting world id: {d}\n", .{world_id});
    game.state.ui.world_loaded_name = name;
    game.state.ui.world_loaded_id = world_id;
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
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const ui = @import("../../../ui.zig");
const screen_helpers = @import("../screen_helpers.zig");
const helpers = @import("ui_helpers.zig");
