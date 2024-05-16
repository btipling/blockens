const system_name = "ScreenRotatingSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.OnLoad, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.Screen) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.screen.WorldRotating) };
    desc.run = if (config.use_tracy) runWithTrace else run;
    return desc;
}

fn runWithTrace(it: *ecs.iter_t) callconv(.C) void {
    ztracy.Message(system_name);
    const tracy_zone = ztracy.ZoneNC(@src(), system_name, 0xff_00_ff_f0);
    defer tracy_zone.End();
    return run(it);
}

const rotation_time: f32 = 1;

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const s = ecs.field(it, components.screen.Screen, 1) orelse continue;
            if (!ecs.has_id(world, s[i].current, ecs.id(components.screen.Settings))) {
                // Rotation attached to unsupported screen.
                ecs.remove(world, entity, components.screen.WorldRotating);
                continue;
            }
            if (!ecs.is_alive(world, s[i].current)) {
                std.debug.print("current {d} is not alive!\n", .{s[i].current});
                return;
            }
            const r = ecs.field(it, components.screen.WorldRotating, 2) orelse continue;

            // To achieve frame rate independent rotation this code increments the rotation of the screen
            // each frame based on the elapsed time since the rotation given the rotation's starting point.
            const now = game.state.input.lastframe;
            const rotation_duration: f32 = now - r[i].started_at;
            if (rotation_duration > rotation_time) {
                ecs.remove(world, entity, components.screen.WorldRotating);
                continue;
            }

            // slerp
            const current_rot = zm.slerp(r[i].start_rotation, r[i].end_rotation, rotation_duration / rotation_time);

            // Set the rotation value, only settings screens can be rotated, so camera is hard coded here.
            var world_rotation: *components.screen.WorldRotation = ecs.get_mut(
                world,
                game.state.entities.settings_camera,
                components.screen.WorldRotation,
            ) orelse @panic("settings screen has no world rotation");
            world_rotation.rotation = current_rot;

            // Update the rotation stored in state:
            const xyz: [3]f32 = zm.quatToRollPitchYaw(current_rot);
            game.state.ui.demo_screen_rotation_x = xyz[0];
            game.state.ui.demo_screen_rotation_y = xyz[1];
            game.state.ui.demo_screen_rotation_z = xyz[2];
        }
    }
}

const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const screen_helpers = @import("../screen_helpers.zig");
