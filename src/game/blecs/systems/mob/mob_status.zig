const system_name = "MobStatusSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.mob.Mob) };
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
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const current_ar: u32 = game.state.gfx.animation_data.animations_running;
            if (ecs.has_id(world, entity, ecs.id(components.mob.Walking))) {
                game.state.gfx.animation_data.animations_running = current_ar | gfx.constants.DemoCharacterWalkingAnimationID;
            } else if (ecs.has_id(world, entity, ecs.id(components.mob.Turning))) {
                game.state.gfx.animation_data.animations_running = current_ar | gfx.constants.DemoCharacterWalkingAnimationID;
            } else if (ecs.has_id(world, entity, ecs.id(components.mob.Jumping))) {
                game.state.gfx.animation_data.animations_running = current_ar | gfx.constants.DemoCharacterWalkingAnimationID;
            } else {
                game.state.gfx.animation_data.animations_running = current_ar & ~gfx.constants.DemoCharacterWalkingAnimationID;
            }
        }
    }
}

const std = @import("std");
const ecs = @import("zflecs");
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../components/components.zig");
const helpers = @import("../../helpers.zig");
const game = @import("../../../game.zig");
const game_state = @import("../../../state.zig");
const cltf_mesh = @import("../../../gfx/cltf_mesh.zig");
const gfx = @import("../../../gfx/gfx.zig");
