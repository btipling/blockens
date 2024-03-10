const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const game_state = @import("../../../state/state.zig");
const screen_helpers = @import("../screen_helpers.zig");
const helpers = @import("ui_helpers.zig");

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
            const xPos: f32 = 1500.0;
            const yPos: f32 = 800.0;
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = 800,
                .h = 500,
            });
            if (zgui.begin("#TitleScreen", .{
                .flags = zgui.WindowFlags.no_decoration,
            })) {
                zgui.text("Blockens!", .{});
                const ww = zgui.getWindowWidth();
                zgui.newLine();
                zgui.newLine();
                zgui.sameLine(.{
                    .offset_from_start_x = ww / 2 - 250,
                    .spacing = 20,
                });
                if (zgui.button("Settings", .{
                    .w = 450,
                    .h = 100,
                })) {
                    screen_helpers.showWorldEditor();
                }
                var default_world: i32 = 0;
                zgui.newLine();
                zgui.sameLine(.{
                    .offset_from_start_x = ww / 2 - 250,
                    .spacing = 20,
                });

                var combo: bool = false;
                var cw: bool = false;
                for (game.state.ui.data.world_options.items, 0..) |worldOption, i| {
                    var buffer: [game_state.max_world_name + 10]u8 = undefined;
                    const selectableName = std.fmt.bufPrint(
                        &buffer,
                        "{d}: {s}",
                        .{ worldOption.id, worldOption.name },
                    ) catch unreachable;
                    var name: [game_state.max_world_name:0]u8 = undefined;
                    for (name, 0..) |_, ii| {
                        if (selectableName.len <= ii) {
                            name[ii] = 0;
                            break;
                        }
                        name[ii] = selectableName[ii];
                    }
                    if (i == 0) {
                        combo = zgui.beginCombo("##listbox", .{
                            .preview_value = &name,
                        });
                        cw = zgui.beginPopupContextWindow();
                        default_world = worldOption.id;
                    }
                    std.debug.print("selectable - {s} combo: {} cw: {}\n", .{ name, combo, cw });
                    if (combo and cw) {
                        std.debug.print("selectable? {s}\n", .{name});
                        if (zgui.selectable(&name, .{})) {
                            loadWorld(worldOption.id);
                        }
                    }
                }
                if (cw) zgui.endPopup();
                if (combo) zgui.endCombo();

                zgui.newLine();
                zgui.sameLine(.{
                    .offset_from_start_x = ww / 2 - 250,
                    .spacing = 20,
                });
                if (zgui.button("Play", .{
                    .w = 450,
                    .h = 100,
                })) {
                    if (game.state.ui.data.world_loaded_id == 0) game.state.ui.data.world_loaded_id = default_world;
                    screen_helpers.showGameScreen();
                    helpers.loadChunkDatas() catch unreachable;
                    helpers.loadChunksInWorld();
                }
            }
            zgui.end();
        }
    }
}

fn loadWorld(worldId: i32) void {
    game.state.ui.data.world_loaded_id = worldId;
}
