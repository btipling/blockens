pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UIWorldManagementSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.WorldManagement) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = game.state.ui.imguiX(100);
            const yPos: f32 = game.state.ui.imguiY(100);
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .first_use_ever });
            zgui.setNextWindowSize(.{
                .w = game.state.ui.imguiWidth(600),
                .h = game.state.ui.imguiHeight(685),
                .cond = .first_use_ever,
            });
            if (zgui.begin("World Management", .{
                .flags = .{
                    .menu_bar = true,
                },
            })) {
                if (zgui.beginMenuBar()) {
                    if (zgui.menuItem("Close", .{})) {
                        screen_helpers.toggleWorldManagement();
                    }
                    zgui.endMenuBar();
                }
                worldManager() catch @panic("nope");
            }
            zgui.end();
        }
    }
}

fn worldManager() !void {
    const btn_dms: [2]f32 = game.state.ui.imguiButtonDims();
    zgui.text("world list", .{});
    if (helpers.worldChooser(.{
        .world_id = game.state.ui.world_mananaged_id,
        .name = game.state.ui.world_managed_name,
    })) |selected| {
        game.state.ui.world_mananaged_id = selected.world_id;
        game.state.ui.world_managed_name = selected.name;
    }
    if (game.state.ui.world_mananaged_id == 0) return;
    zgui.text("Managing world id {d} - {s}", .{
        game.state.ui.world_mananaged_id,
        std.mem.sliceTo(&game.state.ui.world_managed_name, 0),
    });
    if (zgui.button("Delete World", .{
        .w = btn_dms[0],
        .h = btn_dms[1],
    })) {
        try deleteWorld();
    }
}

fn deleteWorld() !void {
    // TODO: exit exit world if it's the one being deleted
    const world_id = game.state.ui.world_mananaged_id;
    try game.state.db.deleteAllWorldTerrain(world_id);
    try game.state.db.deletePlayerPosition(world_id);
    try game.state.db.deleteChunkData(world_id);
    // TODO: delete gzip chunk data
    try game.state.db.deleteWorld(world_id);
    var index: usize = 0;
    var i: usize = 0;
    while (i < game.state.ui.world_options.items.len) : (i += 1) {
        index = i;
        if (game.state.ui.world_options.items[i].id == world_id) break;
    }
    _ = game.state.ui.world_options.swapRemove(index);
    game.state.ui.world_loaded_id = 0;
    game.state.ui.world_mananaged_id = 0;
}

const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const helpers = @import("ui_helpers.zig");
const screen_helpers = @import("../screen_helpers.zig");
