const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const math = @import("../../../math/math.zig");
const gfx = @import("../../../gfx/gfx.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "MobUpdateSystem", ecs.OnUpdate, @constCast(&s));
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
            var angle: f32 = 0;
            if (ecs.get(world, entity, components.mob.Position)) |p| {
                loc = p.position;
            }
            if (ecs.get(world, entity, components.mob.Rotation)) |r| {
                rotation = r.rotation;
                angle = r.angle;
            }
            ecs.remove(world, entity, components.mob.NeedsUpdate);
            updateMob(world, entity, loc, rotation);
            updateThirdPersonCamera(world, loc, rotation);
            ecs.add(world, entity, components.mob.DidUpdate);
        }
    }
}

fn updateMob(world: *ecs.world_t, entity: ecs.entity_t, loc: @Vector(4, f32), rotation: @Vector(4, f32)) void {
    var i: i32 = 0;
    while (true) {
        const child_entity = ecs.get_target(world, entity, entities.mob.HasMesh, i);
        if (child_entity == 0) break;
        _ = ecs.set(world, child_entity, components.screen.WorldRotation, .{ .rotation = rotation });
        _ = ecs.set(world, child_entity, components.screen.WorldLocation, .{ .loc = loc });
        ecs.add(world, child_entity, components.gfx.NeedsUniformUpdate);
        game.state.ui.data.world_player_relocation = loc;
        i += 1;
    }
    i = 0;
    while (true) {
        const child_entity = ecs.get_target(world, entity, entities.mob.HasBoundingBox, i);
        if (child_entity == 0) break;
        _ = ecs.set(world, child_entity, components.screen.WorldRotation, .{ .rotation = rotation });
        _ = ecs.set(world, child_entity, components.screen.WorldLocation, .{ .loc = loc });
        ecs.add(world, child_entity, components.gfx.NeedsUniformUpdate);
        i += 1;
    }
}

fn updateThirdPersonCamera(world: *ecs.world_t, loc: @Vector(4, f32), rotation: @Vector(4, f32)) void {
    // The player's position is on the ground, we want the cursor position, which is off set up and to the right.
    const cursor_axis: f32 = 1.5;
    var cursor_axis_pos: @Vector(4, f32) = .{ loc[0], loc[1] + cursor_axis, loc[2], loc[3] };

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
        const np = cursor_axis_pos - front_vector;
        // We always normalize our front after changing it.
        cf.front = zm.normalize3(cursor_axis_pos - np);
    }
    {
        // ** This block of code gets us the pitch at which the third person camera front needs to be at **
        // The up vector
        const up: @Vector(4, f32) = .{ 0, 1, 0, 0 };
        // The horizontal axis, based on the camera front right behind player's head around which we rotate the pitch.
        const horizontal_axis = zm.normalize3(zm.cross3(cf.front, up));
        const pitch = cr.pitch * (std.math.pi / 180.0);
        // rotateVector takes the front and horizontal axes, turns them into quaternions and appies rotation via pitch.
        const rotated_front: @Vector(4, f32) = math.vecs.rotateVector(
            cf.front,
            horizontal_axis,
            pitch,
        );
        // The only thing being updated here on the front is the Y, the pitch. The camera's front is already correct otherwise.
        cf.front = @Vector(4, f32){
            cf.front[0],
            zm.normalize3(rotated_front)[1],
            cf.front[2],
            1.0,
        };
        cursor_axis_pos = cursor_axis_pos - cf.front;
    }
    {
        // ** This block block of code is trying to keep the cross hairs to the right of the character.
        // First we get the sign of z, to multiply against the y on the side vector.
        var z: f32 = @ceil(cf.front[2]);
        if (z == 0) z = -1;
        // This gets a vector we can use to get place where the cursor will go with a cross product.
        const left: @Vector(4, f32) = .{ -1, 0, 0, 0 };
        var side_vector = zm.normalize3(zm.cross3(cf.front, left));
        // Keep y to 1 or -1 depending on the sign of z to avoid jumpiness. The goal of here is
        // to just keep the cursor to the right not adjust pitch. We did already.
        var y: f32 = @ceil(side_vector[1]);
        if (y == 0) y = -1;
        side_vector[1] = y * z;

        // The side vector tells us where the cursor should be and now we use it to tell us where
        // the camera will go relative to it.
        const dir_vector = zm.normalize3(zm.cross3(cf.front, side_vector));
        const cursor_axis_pos_adjusted = cursor_axis_pos - dir_vector;
        // Just updating x and z.
        cursor_axis_pos[0] = cursor_axis_pos_adjusted[0];
        cursor_axis_pos[2] = cursor_axis_pos_adjusted[2];
    }
    {
        // ** This block of code positions the camera further back from the head than right behind it **
        const camera_distance_scalar: f32 = 4.5; // TODO make this adjustable so we can look up at things better?
        const camera_distance: @Vector(4, f32) = @splat(camera_distance_scalar);
        cp.pos = cursor_axis_pos - cf.front * camera_distance;
        // TODO: camera collision detection with world around so the camera doesn't pass through objects in the world and the ground.
    }
}
