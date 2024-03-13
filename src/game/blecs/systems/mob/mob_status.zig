const std = @import("std");
const ecs = @import("zflecs");
const components = @import("../../components/components.zig");
const helpers = @import("../../helpers.zig");
const game = @import("../../../game.zig");
const game_state = @import("../../../state.zig");
const cltf_mesh = @import("../../../gfx/cltf_mesh.zig");
const gfx = @import("../../../gfx/gfx.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "MobStatusSystem", ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.mob.Mob) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            if (ecs.has_id(world, entity, ecs.id(components.mob.Walking))) {
                game.state.gfx.animations_running = game.state.gfx.animations_running | gfx.constants.DemoCharacterWalkingAnimationID;
            } else {
                game.state.gfx.animations_running = game.state.gfx.animations_running & ~gfx.constants.DemoCharacterWalkingAnimationID;
            }
        }
    }
}
