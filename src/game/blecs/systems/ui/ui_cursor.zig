const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const gl = @import("zopengl").bindings;
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const screen_helpers = @import("../screen_helpers.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UICursorSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.UI) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const has_cusor = ecs.has_id(
                game.state.world,
                game.state.entities.ui,
                ecs.id(components.ui.Menu),
            );
            if (has_cusor) {
                game.state.window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.normal);
                continue;
            }
            game.state.window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);
        }
    }
}
