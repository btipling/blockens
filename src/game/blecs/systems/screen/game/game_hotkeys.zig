const system_name = "GameHotkeysSystem";

var pressedKeyState: ?glfw.Key = null;

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.OnLoad, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.Game) };
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
    const world = game.state.world;
    const sky_cam = game.state.entities.sky_camera;
    const tpc = game.state.entities.third_person_camera;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            if (ecs.has_id(world, sky_cam, ecs.id(components.screen.CurrentCamera))) {
                pressedKeyState = handleSkyCamKeys() orelse handleSharedKeys() orelse unsetKeyState();
            } else if (ecs.has_id(world, tpc, ecs.id(components.screen.CurrentCamera))) {
                pressedKeyState = handleThirdPlayerCamKeys() orelse handleSharedKeys() orelse unsetKeyState();
            }
        }
    }
}

fn handleSharedKeys() ?glfw.Key {
    if (input.keys.pressedKey(.q)) toggleCamera();
    if (input.keys.holdKey(.F2)) {
        ecs.add(game.state.world, game.state.entities.ui, components.ui.Menu);
        return .F2;
    }

    return null;
}

fn unsetKeyState() ?glfw.Key {
    if (pressedKeyState != null) {
        ecs.remove(game.state.world, game.state.entities.ui, components.ui.Menu);
        pressedKeyState = null;
    }

    if (input.keys.holdKey(.left_control) and input.keys.holdKey(.s)) {
        return saveNow();
    }
    return pressedKeyState;
}

fn saveNow() ?glfw.Key {
    const m: *components.mob.Mob = ecs.get_mut(
        game.state.world,
        game.state.entities.player,
        components.mob.Mob,
    ) orelse return null;
    m.last_saved = 0;
    return null;
}

fn toggleCamera() void {
    // init player camera
    const rotation: *const components.mob.Rotation = ecs.get(
        game.state.world,
        game.state.entities.player,
        components.mob.Rotation,
    ) orelse return;
    var position: *components.mob.Position = ecs.get_mut(
        game.state.world,
        game.state.entities.player,
        components.mob.Position,
    ) orelse return;
    _ = &position;
    const rot = rotation.rotation;
    const pos = position.position;

    const front_vector: @Vector(4, f32) = zm.rotate(rot, gfx.cltf.forward_vec);
    const np = pos + front_vector;
    position.position = np;
    ecs.add(game.state.world, game.state.entities.player, components.mob.NeedsUpdate);
    entities.screen.toggleCamera();
}

fn handleThirdPlayerCamKeys() ?glfw.Key {
    if (input.keys.holdKey(.space)) playerJ();
    if (input.keys.holdKey(.w)) {
        playerF(input.keys.holdKey(.left_shift));
        return .w;
    }
    if (input.keys.holdKey(.s)) {
        playerB();
        return .s;
    }
    if (input.keys.holdKey(.d)) {
        playerL();
        return .a;
    }
    if (input.keys.holdKey(.a)) {
        playerR();
        return .d;
    }
    if (input.keys.pressedKey(.right)) {
        changeBlock(1);
        return .d;
    }
    if (input.keys.pressedKey(.left)) {
        changeBlock(-1);
        return .d;
    }
    return null;
}

fn changeBlock(direction: isize) void {
    var it = game.state.blocks.blocks.iterator();
    if (direction > 0) {
        game.state.blocks.selected_block += 1;
        while (it.next()) |e| {
            const block = e.value_ptr.*;
            if (block.id == game.state.blocks.selected_block) return;
        }
        game.state.blocks.selected_block = 1;
        return;
    }
    game.state.blocks.selected_block -= 1;
    var last_block_id: u8 = 0;
    while (it.next()) |e| {
        const block = e.value_ptr.*;
        if (block.id == game.state.blocks.selected_block) return;
        if (block.id > last_block_id) last_block_id = block.id;
    }
    game.state.blocks.selected_block = last_block_id;
}

fn playerRL() void {
    const rotation: *const components.mob.Rotation = ecs.get(
        game.state.world,
        game.state.entities.player,
        components.mob.Rotation,
    ) orelse return;
    const rot = rotation.rotation;
    const up = @Vector(4, f32){ 0.0, 1.0, 0.0, 0.0 };
    const angle = rotation.angle + 0.025;
    const turn = zm.quatFromNormAxisAngle(up, angle * std.math.pi);
    const new_rot: @Vector(4, f32) = zm.rotate(rot, turn);
    const front_vector: @Vector(4, f32) = zm.rotate(new_rot, gfx.cltf.forward_vec);
    _ = ecs.set(game.state.world, game.state.entities.player, components.mob.Turning, .{
        .direction_vector = front_vector,
        .rotation = new_rot,
        .angle = angle,
    });
    ecs.add(game.state.world, game.state.entities.player, components.mob.NeedsUpdate);
}

fn playerRR() void {
    const rotation: *const components.mob.Rotation = ecs.get(
        game.state.world,
        game.state.entities.player,
        components.mob.Rotation,
    ) orelse return;
    const rot = rotation.rotation;
    const up = @Vector(4, f32){ 0.0, 1.0, 0.0, 0.0 };
    const angle = rotation.angle - 0.025;
    const turn = zm.quatFromNormAxisAngle(up, angle * std.math.pi);
    const new_rot: @Vector(4, f32) = zm.rotate(rot, turn);
    const front_vector: @Vector(4, f32) = zm.rotate(new_rot, gfx.cltf.forward_vec);
    _ = ecs.set(game.state.world, game.state.entities.player, components.mob.Turning, .{
        .direction_vector = front_vector,
        .rotation = new_rot,
        .angle = angle,
    });
    ecs.add(game.state.world, game.state.entities.player, components.mob.NeedsUpdate);
}

fn playerF(running: bool) void {
    const rotation: *const components.mob.Rotation = ecs.get(
        game.state.world,
        game.state.entities.player,
        components.mob.Rotation,
    ) orelse return;
    const rot = rotation.rotation;
    const speed_delta: f32 = if (running) 5 else 2.5;
    const speed = speed_delta * game.state.input.delta_time;
    const front_vector: @Vector(4, f32) = zm.rotate(rot, gfx.cltf.forward_vec);
    _ = ecs.set(
        game.state.world,
        game.state.entities.player,
        components.mob.Walking,
        .{
            .direction_vector = front_vector,
            .speed = speed,
            .last_moved = game.state.input.lastframe,
        },
    );
    ecs.add(game.state.world, game.state.entities.player, components.mob.NeedsUpdate);
}

fn playerB() void {
    const rotation: *const components.mob.Rotation = ecs.get(
        game.state.world,
        game.state.entities.player,
        components.mob.Rotation,
    ) orelse return;
    const rot = rotation.rotation;
    const speed_delta: f32 = 2.5;
    const speed = speed_delta * game.state.input.delta_time;
    const inverse: @Vector(4, f32) = @splat(-1);
    const front_vector: @Vector(4, f32) = zm.rotate(rot, gfx.cltf.forward_vec);
    _ = ecs.set(
        game.state.world,
        game.state.entities.player,
        components.mob.Walking,
        .{
            .direction_vector = front_vector * inverse,
            .speed = speed,
            .last_moved = game.state.input.lastframe,
        },
    );
    ecs.add(game.state.world, game.state.entities.player, components.mob.NeedsUpdate);
}

fn playerL() void {
    const rotation: *const components.mob.Rotation = ecs.get(
        game.state.world,
        game.state.entities.player,
        components.mob.Rotation,
    ) orelse return;
    const camera_up: *const components.screen.UpDirection = ecs.get(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.UpDirection,
    ) orelse return;
    const rot = rotation.rotation;
    const speed_delta: f32 = 2.5;
    const speed = speed_delta * game.state.input.delta_time;
    const front_vector: @Vector(4, f32) = zm.rotate(rot, gfx.cltf.forward_vec);
    _ = ecs.set(
        game.state.world,
        game.state.entities.player,
        components.mob.Walking,
        .{
            .direction_vector = zm.normalize3(zm.cross3(front_vector, camera_up.up)),
            .speed = speed,
            .last_moved = game.state.input.lastframe,
        },
    );
    ecs.add(game.state.world, game.state.entities.player, components.mob.NeedsUpdate);
}

fn playerR() void {
    const rotation: *const components.mob.Rotation = ecs.get(
        game.state.world,
        game.state.entities.player,
        components.mob.Rotation,
    ) orelse return;
    const camera_up: *const components.screen.UpDirection = ecs.get(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.UpDirection,
    ) orelse return;
    const rot = rotation.rotation;
    const speed_delta: f32 = 2.5;
    const speed = speed_delta * game.state.input.delta_time;
    const inverse: @Vector(4, f32) = @splat(-1);
    const front_vector: @Vector(4, f32) = zm.rotate(rot, gfx.cltf.forward_vec);
    _ = ecs.set(
        game.state.world,
        game.state.entities.player,
        components.mob.Walking,
        .{
            .direction_vector = zm.normalize3(zm.cross3(front_vector, camera_up.up)) * inverse,
            .speed = speed,
            .last_moved = game.state.input.lastframe,
        },
    );
    ecs.add(game.state.world, game.state.entities.player, components.mob.NeedsUpdate);
}

fn playerJ() void {
    const world = game.state.world;
    const player = game.state.entities.player;
    if (ecs.has_id(world, player, ecs.id(components.mob.Jumping))) {
        return;
    }
    if (ecs.has_id(world, player, ecs.id(components.mob.Falling))) {
        return;
    }
    var loc: @Vector(4, f32) = undefined;
    if (ecs.get(world, player, components.mob.Position)) |p| {
        loc = p.position;
    } else std.debug.panic("expected a location when starting a jump\n", .{});
    _ = ecs.set(
        world,
        game.state.entities.player,
        components.mob.Jumping,
        .{
            .starting_position = loc,
            .jumped_at = game.state.input.lastframe,
        },
    );
}

fn getSpeed() f32 {
    var speed = 2.5 * game.state.input.delta_time;
    if (!input.keys.holdKey(.left_control)) speed *= 20;
    return speed;
}

fn handleSkyCamKeys() ?glfw.Key {
    if (input.keys.holdKey(.w)) skyCamF();
    if (input.keys.holdKey(.s)) skyCamB();
    if (input.keys.holdKey(.a)) skyCamL();
    if (input.keys.holdKey(.d)) skyCamR();
    if (input.keys.holdKey(.space)) skyCamU();
    if (input.keys.holdKey(.left_shift)) skyCamD();
    if (input.keys.holdKey(.up)) {
        playerF(false);
        return .up;
    } else if (input.keys.holdKey(.left)) {
        playerRL();
        return .left;
    } else if (input.keys.holdKey(.right)) {
        playerRR();
        return .right;
    }
    return null;
}

fn skyCamF() void {
    const camera_front: *const components.screen.CameraFront = ecs.get(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.CameraFront,
    ) orelse return;
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.CameraPosition,
    ) orelse return;
    _ = &camera_pos;
    const cf = camera_front.front;
    const cp = camera_pos.pos;
    const speed = getSpeed();
    const camera_speed: @Vector(4, f32) = @splat(speed);
    const np = cp + cf * camera_speed;
    updateConditionally(camera_pos, np, cp);
}

fn skyCamB() void {
    const camera_front: *const components.screen.CameraFront = ecs.get(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.CameraFront,
    ) orelse return;
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.CameraPosition,
    ) orelse return;
    _ = &camera_pos;
    const cf = camera_front.front;
    const cp = camera_pos.pos;
    const speed = getSpeed();
    const camera_speed: @Vector(4, f32) = @splat(speed);
    const np = cp - cf * camera_speed;
    updateConditionally(camera_pos, np, cp);
}

fn skyCamL() void {
    const camera_front: *const components.screen.CameraFront = ecs.get(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.CameraFront,
    ) orelse return;
    const camera_up: *const components.screen.UpDirection = ecs.get(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.UpDirection,
    ) orelse return;
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.CameraPosition,
    ) orelse return;
    _ = &camera_pos;
    const cf = camera_front.front;
    const cu = camera_up.up;
    const cp = camera_pos.pos;
    const speed = getSpeed();
    const camera_speed: @Vector(4, f32) = @splat(speed);
    const np = cp - zm.normalize3(zm.cross3(cf, cu)) * camera_speed;
    updateConditionally(camera_pos, np, cp);
}

fn skyCamR() void {
    const camera_front: *const components.screen.CameraFront = ecs.get(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.CameraFront,
    ) orelse return;
    const camera_up: *const components.screen.UpDirection = ecs.get(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.UpDirection,
    ) orelse return;
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.CameraPosition,
    ) orelse return;
    _ = &camera_pos;
    const cf = camera_front.front;
    const cu = camera_up.up;
    const cp = camera_pos.pos;
    const speed = getSpeed();
    const camera_speed: @Vector(4, f32) = @splat(speed);
    const np = cp + zm.normalize3(zm.cross3(cf, cu)) * camera_speed;
    updateConditionally(camera_pos, np, cp);
}

fn skyCamU() void {
    const camera_up: *const components.screen.UpDirection = ecs.get(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.UpDirection,
    ) orelse return;
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.CameraPosition,
    ) orelse return;
    _ = &camera_pos;
    const cu = camera_up.up;
    const cp = camera_pos.pos;
    const speed = getSpeed();
    const camera_speed: @Vector(4, f32) = @splat(speed);
    const up_direction: @Vector(4, f32) = @splat(1.0);
    const np = cp + cu * camera_speed * up_direction;
    updateConditionally(camera_pos, np, cp);
}

fn skyCamD() void {
    const camera_up: *const components.screen.UpDirection = ecs.get(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.UpDirection,
    ) orelse return;
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.CameraPosition,
    ) orelse return;
    _ = &camera_pos;
    const cu = camera_up.up;
    const cp = camera_pos.pos;
    const speed = getSpeed();
    const camera_speed: @Vector(4, f32) = @splat(speed);
    const down_direction: @Vector(4, f32) = @splat(-1.0);
    const np = cp + cu * camera_speed * down_direction;
    updateConditionally(camera_pos, np, cp);
}

fn updateConditionally(camera_pos: *components.screen.CameraPosition, np: [4]f32, cp: [4]f32) void {
    if (std.mem.eql(f32, &np, &cp)) return;
    camera_pos.pos = np;
    ecs.add(
        game.state.world,
        game.state.entities.sky_camera,
        components.screen.Updated,
    );
}
const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const glfw = @import("zglfw");
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../../components/components.zig");
const entities = @import("../../../entities/entities.zig");
const game = @import("../../../../game.zig");
const input = @import("../../../../input/input.zig");
const gfx = @import("../../../../gfx/gfx.zig");
