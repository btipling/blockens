const std = @import("std");
const ecs = @import("zflecs");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const helpers = @import("../../helpers.zig");
const game = @import("../../../game.zig");
const game_state = @import("../../../state.zig");
const cltf_mesh = @import("../../../gfx/cltf_mesh.zig");
const gfx = @import("../../../gfx/gfx.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "MobBoundingBoxSetupSystem", ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.mob.BoundingBox) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.mob.NeedsSetup) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const m: []components.mob.BoundingBox = ecs.field(it, components.mob.BoundingBox, 1) orelse continue;
            ecs.remove(world, entity, components.mob.NeedsSetup);
            const ok = setupBoundingBox(world, entity, m[i].mob_entity) catch @panic("nope");
            if (!ok) std.debug.panic("unable to set up bounding box.\n", .{});
        }
    }
}

fn setupBoundingBox(world: *ecs.world_t, entity: ecs.entity_t, parent: ecs.entity_t) !bool {
    const m: *const components.mob.Mob = ecs.get(world, parent, components.mob.Mob) orelse return false;
    const data_entity = m.data_entity;

    const is_demo = data_entity == entities.screen.settings_data;
    var loc: @Vector(4, f32) = .{ 1, 1, 1, 1 };
    var rotation: @Vector(4, f32) = .{ 0, 0, 0, 1 };

    if (ecs.get(world, entity, components.mob.Position)) |p| {
        loc = p.position;
    }
    if (ecs.get(world, entity, components.mob.Rotation)) |r| {
        rotation = r.rotation;
    }
    _ = ecs.set(world, entity, components.shape.Shape, .{ .shape_type = .bounding_box });
    {
        std.debug.print("setting bb location to ({d}, {d}, {d}, {d})\n", .{
            loc[0],
            loc[1],
            loc[2],
            loc[3],
        });
        _ = ecs.set(world, entity, components.screen.WorldLocation, .{ .loc = loc });
        _ = ecs.set(world, entity, components.screen.WorldRotation, .{ .rotation = rotation });
        if (is_demo) {
            _ = ecs.set(world, entity, components.shape.UBO, .{ .binding_point = gfx.constants.SettingsUBOBindingPoint });
        } else {
            _ = ecs.set(world, entity, components.shape.UBO, .{ .binding_point = gfx.constants.GameUBOBindingPoint });
        }
    }
    ecs.add(world, entity, components.gfx.ManuallyHidden);
    // ecs.add(world, entity, components.Debug);
    ecs.add(world, entity, components.shape.NeedsSetup);
    return true;
}
