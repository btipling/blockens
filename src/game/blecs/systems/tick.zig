pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "TickSystem", ecs.OnUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.Time) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const t: []components.Time = ecs.field(it, components.Time, 1) orelse return;
            const now = std.time.milliTimestamp();
            t[i].currentTime = now;
            if (t[i].startTime == 0) {
                t[i].startTime = now;
            }
        }
    }
}

const std = @import("std");
const ecs = @import("zflecs");
const components = @import("../components/components.zig");
const game = @import("../../game.zig");
