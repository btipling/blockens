const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const components = @import("../components/components.zig");
const game = @import("../../game.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "SkySystem", ecs.OnUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.Sky) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const s: []components.Sky = ecs.field(it, components.Sky, 1) orelse return;
            const t: *components.Time = ecs.get_mut(world, game.state.entities.clock, components.Time) orelse return;
            const br: *components.gfx.BaseRenderer = ecs.get_mut(world, game.state.entities.gfx, components.gfx.BaseRenderer) orelse return;
            var brightness = br.bgColor.getBrightness();
            if (s[i].lastSet == 0) {
                s[i].lastSet = t.currentTime;
            }
            const enoughTimeElapsed = s[i].lastSet == 0 or (t.currentTime - s[i].lastSet) > 100;
            if (!enoughTimeElapsed) {
                continue;
            }
            s[i].lastSet = t.currentTime;
            switch (s[i].sun) {
                .rising => {
                    if (brightness >= 0.9) {
                        s[i].sun = .setting;
                        continue;
                    }
                    brightness += 0.001;
                },
                .setting => {
                    if (brightness <= 0.1) {
                        s[i].sun = .rising;
                        continue;
                    }
                    brightness -= 0.001;
                },
            }

            br.bgColor.setBrightness(@min(@max(brightness, 0.1), 0.9));
        }
    }
}
