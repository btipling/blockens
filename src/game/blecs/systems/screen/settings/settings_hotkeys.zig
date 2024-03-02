const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const components = @import("../../../components/components.zig");
const game = @import("../../../../game.zig");
const input = @import("../../../../input/input.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "SettingsHotkeysSystem", ecs.OnLoad, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.Settings) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    const screen: *const components.screen.Screen = ecs.get(
        world,
        game.state.entities.screen,
        components.screen.Screen,
    ) orelse unreachable;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            if (ecs.has_id(world, screen.current, ecs.id(components.screen.ChunkEditor))) {
                handleChunkHotKeys();
            }
        }
    }
}

fn handleChunkHotKeys() void {
    if (input.keys.holdKey(.left)) {
        var world_rotation: *components.screen.WorldRotation = ecs.get_mut(
            game.state.world,
            game.state.entities.settings_camera,
            components.screen.WorldRotation,
        ) orelse return;
        const m = zm.quatToMat(world_rotation.rotation);
        const r = zm.rotationY(0.0125 * std.math.pi * 2.0);
        world_rotation.rotation = zm.matToQuat(zm.mul(m, r));
    }
    if (input.keys.holdKey(.right)) {
        var world_rotation: *components.screen.WorldRotation = ecs.get_mut(
            game.state.world,
            game.state.entities.settings_camera,
            components.screen.WorldRotation,
        ) orelse return;
        const m = zm.quatToMat(world_rotation.rotation);
        const r = zm.rotationY(-0.0125 * std.math.pi * 2.0);
        world_rotation.rotation = zm.matToQuat(zm.mul(m, r));
    }
}
