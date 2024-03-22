const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const math = @import("../../../math/math.zig");
const gfx = @import("../../../gfx/gfx.zig");

const save_after_seconds: f64 = 5;

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
            const m: []components.mob.Mob = ecs.field(it, components.mob.Mob, 1) orelse return;
            var loc: @Vector(4, f32) = .{ 1, 1, 1, 1 };
            var rotation: @Vector(4, f32) = .{ 0, 0, 0, 1 };
            var angle: f32 = 0;
            if (ecs.get(world, entity, components.mob.Position)) |p| {
                loc = p.position;
            }
            if (ecs.get(world, entity, components.mob.Rotation)) |r| {
                rotation = r.rotation;
                angle = r.angle;
            }
            updateMob(world, entity, loc, rotation);
            updateThirdPersonCamera(world, loc, rotation);
            if (m[i].last_saved + save_after_seconds < game.state.input.lastframe) {
                _ = game.state.jobs.save();
            }
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
    // The player's position is on the ground, we want the head position, which is about 2 world coordinates higher.
    const head_height: f32 = 2;
    const player_head_pos: @Vector(4, f32) = .{ loc[0], loc[1] + head_height, loc[2], loc[3] };

    // Get a bunch of data.
    const tpc = game.state.entities.third_person_camera;
    var cp: *components.screen.CameraPosition = ecs.get_mut(world, tpc, components.screen.CameraPosition) orelse return;
    var cf: *components.screen.CameraFront = ecs.get_mut(world, tpc, components.screen.CameraFront) orelse return;
    const cr: *const components.screen.CameraRotation = ecs.get(world, tpc, components.screen.CameraRotation) orelse return;

    {
        // ** This block of code locks the third party's camera rotation to always be facing the same direction as the player. **
        // front_vector is the direction the player is facing, using the modified forward vec because of clft format specific adjustments.
        const front_vector: @Vector(4, f32) = zm.rotate(rotation, gfx.cltf.forward_vec);
        // This basically puts the third person camera directly behind the player's head at all times.
        const np = player_head_pos - front_vector;
        // We always normalize our front after changing it.
        cf.front = zm.normalize4(player_head_pos - np);
    }
    {
        // ** This block of code gets us the pitch at which the third person camera front needs to be at **
        // The up vector
        const up: @Vector(4, f32) = .{ 0, 1, 0, 0 };
        // The horizontal axis, based on the camera front right behind player's head around which we rotate the pitch.
        const horizontal_axis = zm.normalize4(zm.cross3(cf.front, up));
        const pitch = cr.pitch * (std.math.pi / 180.0);
        // rotateVector takes the front and horizontal axes, turns them into quaternions and appies rotation via pitch.
        const rotated_front = math.vecs.rotateVector(cf.front, horizontal_axis, pitch);
        // The only thing being updated here on the front is the Y, the pitch. The camera's front is already correct otherwise.
        cf.front = @Vector(4, f32){
            cf.front[0],
            zm.normalize4(rotated_front)[1],
            cf.front[2],
            1.0,
        };
    }
    {
        // ** This block of code positions the camera further back from the head than right behind it **
        const camera_distance_scalar: f32 = 4.5;
        const camera_distance: @Vector(4, f32) = @splat(camera_distance_scalar);
        cp.pos = player_head_pos - cf.front * camera_distance;
        // TODO: camera collision detection with world around so the camera doesn't pass through objects in the world and the ground.
    }
}
