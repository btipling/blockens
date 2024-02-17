const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const components = @import("../../../components/components.zig");
const game = @import("../../../../game.zig");
const input = @import("../../../../input/input.zig");

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
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            if (input.keys.pressedKey(.F3)) {
                std.debug.print("F3 pressed on game screen!\n", .{});
            }
        }
    }
}
