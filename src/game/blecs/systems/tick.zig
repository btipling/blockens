const system_name = "TickSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.PreFrame, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.Time) };
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
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            game.state.ui.gfx_meshes_drawn = game.state.ui.gfx_meshes_drawn_counter;
            game.state.ui.gfx_meshes_drawn_counter = 0;
            const t: []components.Time = ecs.field(it, components.Time, 1) orelse return;
            const now = std.time.milliTimestamp();
            if (@mod(now, 1000) < @mod(t[i].currentTime, 1000)) {
                calculateMetrics();
            }
            t[i].currentTime = now;
            if (t[i].startTime == 0) {
                t[i].startTime = now;
            }
        }
    }
}

fn calculateMetrics() void {}

const std = @import("std");
const ecs = @import("zflecs");
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../components/components.zig");
const game = @import("../../game.zig");
