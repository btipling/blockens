const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const components = @import("../../../components/components.zig");
const game = @import("../../../../game.zig");
const input = @import("../../../../input/input.zig");

var pressedKeyState: ?glfw.Key = null;

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "GameHotkeysSystem", ecs.OnLoad, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.Game) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const menu: *components.ui.Menu = ecs.get_mut(
        game.state.world,
        game.state.entities.menu,
        components.ui.Menu,
    ) orelse unreachable;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            if (input.keys.holdKey(.F3)) {
                menu.visible = true;
                pressedKeyState = .F3;
            } else {
                if (pressedKeyState) |k| {
                    switch (k) {
                        .F3 => {
                            menu.visible = false;
                            pressedKeyState = null;
                        },
                        else => {},
                    }
                }
            }
        }
    }
}
