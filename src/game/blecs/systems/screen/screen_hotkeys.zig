const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");

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
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            std.debug.print("{d}\n", .{i});
        }
    }
}
