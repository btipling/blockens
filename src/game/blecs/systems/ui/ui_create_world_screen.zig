pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UICreateWorldSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.CreateWorldScreen) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = game.state.ui.imguiX(660);
            const yPos: f32 = game.state.ui.imguiY(100);
            const btn_dms: [2]f32 = game.state.ui.imguiButtonDims();
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = game.state.ui.imguiWidth(600),
                .h = game.state.ui.imguiHeight(685),
                .cond = .always,
            });
            if (zgui.begin("Create a world", .{
                .flags = .{
                    .no_resize = true,
                    .no_scrollbar = true,
                    .no_collapse = true,
                },
            })) {
                const ww = zgui.getWindowWidth();
                zgui.newLine();

                centerNext(ww, 125);
                zgui.pushFont(game.state.ui.codeFont);
                zgui.pushItemWidth(game.state.ui.imguiWidth(200));
                _ = zgui.inputTextWithHint("Name", .{
                    .buf = game.state.ui.world_name_buf[0..],
                    .hint = "world name",
                });

                centerNext(ww, 125);
                _ = zgui.inputInt("Seed", .{
                    .v = &game.state.ui.terrain_gen_seed,
                });
                zgui.popItemWidth();
                zgui.popFont();

                centerNext(ww, 250);
                zgui.text("Select terrain generators", .{});

                centerNext(ww, 250);
                var params: helpers.ScriptOptionsParams = .{};
                if (helpers.scriptOptionsListBox(
                    "##so_available",
                    game.state.ui.terrain_gen_script_options_available,
                    &params,
                )) |scriptOptionId| {
                    std.debug.print("selected script: {}\n", .{scriptOptionId});
                    game.state.ui.TerrainGenSelectScript(scriptOptionId);
                }
                zgui.sameLine(.{});
                if (helpers.scriptOptionsListBox(
                    "##so_selected",
                    game.state.ui.terrain_gen_script_options_selected,
                    &params,
                )) |scriptOptionId| {
                    std.debug.print("selected script: {}\n", .{scriptOptionId});
                    game.state.ui.TerrainGenDeselectScript(scriptOptionId);
                }

                centerNext(ww, 125);
                if (zgui.button("Create World", .{
                    .w = btn_dms[0],
                    .h = btn_dms[1],
                })) {
                    // generate world
                }
            }
            zgui.end();
        }
    }
}

fn createWorld() !void {
    game.state.db.saveWorld(
        game.state.ui.world_name_buf,
        game.state.ui.terrain_gen_seed,
    ) catch @panic("db error");
    const world_id = game.state.db.getNewestWorldId() catch @panic("db error");
    var i: usize = 0;
    while (i < game.state.ui.world_gen_scripts_size) : (i += 1) {
        const si = game.state.ui.world_gen_scripts[i];
        game.state.db.saveWorldTerrain(world_id, si) catch @panic("db error");
    }
    game.state.ui.clearWorldGenScripts();
}

fn centerNext(ww: f32, w: f32) void {
    zgui.newLine();
    zgui.newLine();
    zgui.sameLine(.{
        .offset_from_start_x = ww / 2 - game.state.ui.imguiWidth(w),
        .spacing = game.state.ui.imguiWidth(10),
    });
}

const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const helpers = @import("ui_helpers.zig");
const components = @import("../../components/components.zig");
const screen_helpers = @import("../screen_helpers.zig");
const game = @import("../../../game.zig");
