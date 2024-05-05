pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "ScreenHotkeysSystem", ecs.OnLoad, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.Screen) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    const screen: *const components.screen.Screen = ecs.get(
        game.state.world,
        game.state.entities.screen,
        components.screen.Screen,
    ) orelse unreachable;
    if (!ecs.is_alive(world, screen.current)) {
        std.debug.print("current {d} is not alive!\n", .{screen.current});
        return;
    }
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            if (input.keys.pressedKey(.F1)) {
                screen_helpers.toggleScreens();
            }
        }
    }
}

const std = @import("std");
const ecs = @import("zflecs");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const input = @import("../../../input/input.zig");
const screen_helpers = @import("../screen_helpers.zig");
