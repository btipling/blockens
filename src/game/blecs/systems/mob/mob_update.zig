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

var prev_z: f64 = 0;

fn updateThirdPersonCamera(world: *ecs.world_t, loc: @Vector(4, f32), rotation: @Vector(4, f32)) void {
    // The player's position is on the ground, we want the head position, which is about 2 world coordinates higher.
    const loc_hp: @Vector(4, f64) = @floatCast(loc);
    const head_height: f64 = 1.5;
    var player_head_pos: @Vector(4, f64) = .{ loc_hp[0], loc_hp[1] + head_height, loc_hp[2], loc_hp[3] };

    // Get a bunch of data.
    const tpc = game.state.entities.third_person_camera;
    var cp: *components.screen.CameraPosition = ecs.get_mut(world, tpc, components.screen.CameraPosition) orelse return;
    var cf: *components.screen.CameraFront = ecs.get_mut(world, tpc, components.screen.CameraFront) orelse return;
    const cr: *const components.screen.CameraRotation = ecs.get(world, tpc, components.screen.CameraRotation) orelse return;

    var cf_front_hp: @Vector(4, f64) = @floatCast(zm.normalize3(cf.front));
    {
        // ** This block of code locks the third party's camera rotation to always be facing the same direction as the player. **
        // front_vector is the direction the player is facing, using the modified forward vec because of clft format specific adjustments.
        const front_vector: @Vector(4, f64) = @floatCast(zm.rotate(rotation, gfx.cltf.forward_vec));
        // This basically puts the third person camera directly behind the player's head at all times.
        const np = player_head_pos - front_vector;
        // We always normalize our front after changing it.
        cf_front_hp = hp_norm(player_head_pos - np);
    }
    {
        // ** This block of code gets us the pitch at which the third person camera front needs to be at **
        // The up vector
        const up: @Vector(4, f64) = .{ 0, 1, 0, 0 };
        // The horizontal axis, based on the camera front right behind player's head around which we rotate the pitch.
        const horizontal_axis = hp_norm(hp_cross(cf_front_hp, up));
        const pitch = cr.pitch * (std.math.pi / 180.0);
        // rotateVector takes the front and horizontal axes, turns them into quaternions and appies rotation via pitch.
        const rotated_front: @Vector(4, f64) = @floatCast(math.vecs.rotateVector(
            @floatCast(cf_front_hp),
            @floatCast(horizontal_axis),
            pitch,
        ));
        // The only thing being updated here on the front is the Y, the pitch. The camera's front is already correct otherwise.
        cf_front_hp = @Vector(4, f64){
            cf_front_hp[0],
            hp_norm(rotated_front)[1],
            cf_front_hp[2],
            1.0,
        };
        player_head_pos = player_head_pos - cf_front_hp;
    }
    {
        var z: f64 = @ceil(cf_front_hp[2]);
        if (z == 0) z = -1;
        if (prev_z != z) std.debug.print("\n", .{});
        prev_z = z;

        const side_offset: @Vector(4, f64) = @splat(1);
        const z_sign: @Vector(4, f64) = @splat(z);
        const left: @Vector(4, f64) = .{ -1, 0, 0, 0 };
        var side_vector = hp_norm(hp_cross(cf_front_hp, left));
        var y: f64 = @ceil(side_vector[1]);
        if (y == 0) y = -1;
        side_vector[1] = y;

        const dir_vector = hp_norm(hp_cross(cf_front_hp, side_vector * z_sign));

        const php_hp: @Vector(4, f64) = @floatCast(player_head_pos);
        const offset_dir = dir_vector * side_offset;
        const php_adjusted = php_hp - offset_dir;
        player_head_pos[0] = @floatCast(php_adjusted[0]);
        player_head_pos[2] = @floatCast(php_adjusted[2]);
    }
    {
        // ** This block of code positions the camera further back from the head than right behind it **
        const camera_distance_scalar: f32 = 4.5;
        const camera_distance: @Vector(4, f64) = @splat(camera_distance_scalar);
        cp.pos = @floatCast(player_head_pos - cf_front_hp * camera_distance);
        cf.front = @floatCast(cf_front_hp);
        // TODO: camera collision detection with world around so the camera doesn't pass through objects in the world and the ground.
    }
}

fn hp_cross(a: @Vector(4, f64), b: @Vector(4, f64)) @Vector(4, f64) {
    return @Vector(4, f64){
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
        0,
    };
}

fn hp_norm(v: @Vector(4, f64)) @Vector(4, f64) {
    const magnitude = @sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2] + v[3] * v[3]);
    return @Vector(4, f64){
        v[0] / magnitude,
        v[1] / magnitude,
        v[2] / magnitude,
        v[3] / magnitude,
    };
}
