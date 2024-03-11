const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "MobUpdateSystem", ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.mob.Mob) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.mob.NeedsUpdate) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            var loc: @Vector(4, f32) = .{ 1, 1, 1, 1 };
            var rotation: @Vector(4, f32) = .{ 0, 0, 0, 1 };
            if (ecs.get(world, entity, components.mob.Position)) |p| {
                loc = p.position;
            }
            if (ecs.get(world, entity, components.mob.Rotation)) |r| {
                rotation = r.rotation;
            }
            updateMob(world, entity, loc, rotation);
            updateThirdPersonCamera(world, loc, rotation);
        }
    }
}

fn updateMob(world: *ecs.world_t, entity: ecs.entity_t, loc: @Vector(4, f32), rotation: @Vector(4, f32)) void {
    ecs.remove(world, entity, components.mob.NeedsUpdate);
    var i: i32 = 0;
    while (true) {
        const child_entity = ecs.get_target(world, entity, entities.mob.HasMesh, i);
        if (child_entity == 0) break;
        _ = ecs.set(world, child_entity, components.screen.WorldRotation, .{ .rotation = rotation });
        _ = ecs.set(world, child_entity, components.screen.WorldLocation, .{ .loc = loc });
        ecs.add(world, child_entity, components.gfx.NeedsUniformUpdate);
        i += 1;
    }
}

fn updateThirdPersonCamera(world: *ecs.world_t, loc: @Vector(4, f32), rotation: @Vector(4, f32)) void {
    const tpc = game.state.entities.third_person_camera;
    var cp: *components.screen.CameraPosition = ecs.get_mut(world, tpc, components.screen.CameraPosition) orelse return;
    var cf: *components.screen.CameraFront = ecs.get_mut(world, tpc, components.screen.CameraFront) orelse return;
    const cu: *const components.screen.UpDirection = ecs.get(world, tpc, components.screen.UpDirection) orelse return;
    const forward = cu.up;
    const front_vector: @Vector(4, f32) = zm.rotate(rotation, forward);
    const camera_distance: @Vector(4, f32) = @splat(5);
    const np = loc - front_vector * camera_distance;
    cf.front = front_vector;
    cp.pos = np;
}
