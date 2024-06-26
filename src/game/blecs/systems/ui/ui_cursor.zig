const system_name = "UICursorSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.UI) };
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
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const ui: []components.ui.UI = ecs.field(it, components.ui.UI, 1) orelse continue;
            var has_cursor = ecs.has_id(
                world,
                game.state.entities.ui,
                ecs.id(components.ui.Menu),
            );
            if (ui[i].dialog_count > 0) {
                has_cursor = true;
            }
            if (has_cursor) {
                game.state.window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.normal);
                continue;
            }
            game.state.window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);
        }
    }
}

const std = @import("std");
const ecs = @import("zflecs");
const glfw = @import("zglfw");
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const screen_helpers = @import("../screen_helpers.zig");
