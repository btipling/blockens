const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const components = @import("../components.zig");
const game = @import("../../game.zig");

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.Sky) };
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const s: []components.Sky = ecs.field(it, components.Sky, 1) orelse return;
            const t: *components.Time = ecs.get_mut(world, game.state.entities.clock, components.Time) orelse return;
            const br: *components.BaseRenderer = ecs.get_mut(world, game.state.entities.gfx, components.BaseRenderer) orelse return;
            const dm: i64 = 20_000;
            const dv: i64 = @mod(t.currentTime, dm);
            var darkness: gl.Float = ((@as(gl.Float, @floatFromInt(dv))) / dm) / 2;
            var b: gl.Float = darkness * 2.0;
            if (s[i].lastSet == 0) {
                s[i].lastSet = t.currentTime;
            }
            const enoughTimeElapsed = (t.currentTime - s[i].lastSet) > 10_000;
            const shouldSwitch = enoughTimeElapsed and b > 0.999;
            switch (s[i].sun) {
                .rising => {
                    if (shouldSwitch) {
                        s[i].sun = .setting;
                        s[i].lastSet = t.currentTime;
                    }
                },
                .setting => {
                    if (shouldSwitch) {
                        s[i].sun = .rising;
                        s[i].lastSet = t.currentTime;
                    }
                    darkness = 0.5 - darkness;
                    b = 1.0 - b;
                },
            }
            const r = darkness;
            const g = darkness;
            br.bgColor = [4]gl.Float{ r, g, b, 1.0 };
        }
    }
}
