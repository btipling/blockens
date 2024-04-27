pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UITitleScreenSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.TitleScreen) };
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
                .h = game.state.ui.imguiHeight(300),
            });
            if (zgui.begin("#TitleScreen", .{
                .flags = zgui.WindowFlags.no_decoration,
            })) {
                const btn_dms: [2]f32 = game.state.ui.imguiButtonDims();
                zgui.text("Blockens!", .{});
                const ww = zgui.getWindowWidth();
                zgui.newLine();
                zgui.newLine();

                centerNext(ww);
                if (zgui.button("Settings", .{
                    .w = btn_dms[0],
                    .h = btn_dms[1],
                })) {
                    screen_helpers.showWorldEditor();
                }
                var default_world: i32 = 0;

                centerNext(ww);
                var combo: bool = false;
                var cw: bool = false;
                for (game.state.ui.world_options.items, 0..) |world_opt, i| {
                    var buffer: [ui.max_world_name + 10]u8 = undefined;
                    const selectable_name = std.fmt.bufPrint(
                        &buffer,
                        "{d}: {s}",
                        .{ world_opt.id, world_opt.name },
                    ) catch @panic("invalid buffer size");
                    var name: [ui.max_world_name:0]u8 = undefined;
                    for (name, 0..) |_, ii| {
                        if (selectable_name.len <= ii) {
                            name[ii] = 0;
                            break;
                        }
                        name[ii] = selectable_name[ii];
                    }
                    const loaded_world_id = game.state.ui.world_loaded_id;
                    if (i == 0) {
                        var preview_name = &game.state.ui.world_loaded_name;
                        if (loaded_world_id == 0 or loaded_world_id == 1) {
                            default_world = world_opt.id;
                            game.state.ui.world_loaded_id = default_world;
                            preview_name = &name;
                        }
                        zgui.setNextItemWidth(game.state.ui.imguiWidth(250));
                        combo = zgui.beginCombo("##listbox", .{
                            .preview_value = preview_name,
                        });
                        cw = zgui.beginPopupContextWindow();
                    }
                    if (combo) {
                        const selected = world_opt.id == loaded_world_id;
                        if (zgui.selectable(&name, .{ .selected = selected })) {
                            loadWorld(world_opt.id, name);
                        }
                    }
                }
                if (cw) zgui.endPopup();
                if (combo) zgui.endCombo();

                centerNext(ww);
                if (zgui.button("Play", .{
                    .w = btn_dms[0],
                    .h = btn_dms[1],
                })) {
                    if (game.state.ui.world_loaded_id == 0) game.state.ui.world_loaded_id = default_world;
                    const loadedGame = game.state.ui.world_chunk_table_data.count() > 0;
                    if (!loadedGame) {
                        screen_helpers.showLoadingScreen();
                        _ = game.state.jobs.lighting(game.state.ui.world_loaded_id);
                    } else {
                        screen_helpers.showGameScreen();
                    }
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
        .offset_from_start_x = ww / 2 - game.state.ui.imguiWidth(150),
        .spacing = game.state.ui.imguiWidth(10),
    });
}

const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const ui = @import("../../../ui.zig");
const screen_helpers = @import("../screen_helpers.zig");
const helpers = @import("ui_helpers.zig");
const config = @import("../../../config.zig");
