const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const glfw = @import("zglfw");
const components = @import("../../../components/components.zig");
const game = @import("../../../../game.zig");
const input = @import("../../../../input/input.zig");

var pressedKeyState: ?glfw.Key = null;

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "GameHotkeysSystem", ecs.OnLoad, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.Game) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            if (input.keys.holdKey(.w)) skyCamF();
            if (input.keys.holdKey(.s)) skyCamB();
            if (input.keys.holdKey(.a)) skyCamL();
            if (input.keys.holdKey(.d)) skyCamR();
            if (input.keys.holdKey(.space)) skyCamU();
            if (input.keys.holdKey(.left_shift)) skyCamD();
            if (input.keys.holdKey(.F3)) {
                ecs.add(game.state.world, game.state.entities.ui, components.ui.Menu);
                pressedKeyState = .F3;
            } else if (input.keys.holdKey(.up)) {
                playerF();
                pressedKeyState = .up;
            } else if (input.keys.holdKey(.left)) {
                playerRL();
                pressedKeyState = .left;
            } else if (input.keys.holdKey(.right)) {
                playerRR();
                pressedKeyState = .right;
            } else {
                if (pressedKeyState) |k| {
                    switch (k) {
                        .F3 => {
                            ecs.remove(game.state.world, game.state.entities.ui, components.ui.Menu);
                        },
                        .up => playerStop(),
                        .left => playerStop(),
                        .right => playerStop(),
                        else => {},
                    }
                    pressedKeyState = null;
                }
            }
        }
    }
}

fn playerStop() void {
    ecs.remove(game.state.world, game.state.entities.player, components.mob.Walking);
}

fn playerRL() void {
    const rotation: *components.mob.Rotation = ecs.get_mut(
        game.state.world,
        game.state.entities.player,
        components.mob.Rotation,
    ) orelse return;
    _ = &rotation;
    const rot = rotation.rotation;
    const up = @Vector(4, f32){ 0.0, 1.0, 0.0, 0.0 };
    const angle = rotation.angle + 0.025;
    const turn = zm.quatFromNormAxisAngle(up, angle * std.math.pi);
    const new_rot: @Vector(4, f32) = zm.rotate(rot, turn);
    rotation.rotation = new_rot;
    rotation.angle = angle;
    ecs.add(game.state.world, game.state.entities.player, components.mob.Walking);
    ecs.add(game.state.world, game.state.entities.player, components.mob.NeedsUpdate);
}

fn playerRR() void {
    const rotation: *components.mob.Rotation = ecs.get_mut(
        game.state.world,
        game.state.entities.player,
        components.mob.Rotation,
    ) orelse return;
    _ = &rotation;
    const rot = rotation.rotation;
    const up = @Vector(4, f32){ 0.0, 1.0, 0.0, 0.0 };
    const angle = rotation.angle - 0.025;
    const turn = zm.quatFromNormAxisAngle(up, angle * std.math.pi);
    const new_rot: @Vector(4, f32) = zm.rotate(rot, turn);
    rotation.rotation = new_rot;
    rotation.angle = angle;
    ecs.add(game.state.world, game.state.entities.player, components.mob.Walking);
    ecs.add(game.state.world, game.state.entities.player, components.mob.NeedsUpdate);
}

fn playerF() void {
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
    const speed = 2.5 * game.state.input.delta_time;
    const forward = @Vector(4, f32){ 0.0, 0.0, 1.0, 0.0 };
    const player_speed: @Vector(4, f32) = @splat(speed);
    const frontVector: @Vector(4, f32) = zm.rotate(rot, forward);
    const np = pos + frontVector * player_speed;
    position.position = np;
    ecs.add(game.state.world, game.state.entities.player, components.mob.Walking);
    ecs.add(game.state.world, game.state.entities.player, components.mob.NeedsUpdate);
}

fn getSpeed() f32 {
    var speed = 2.5 * game.state.input.delta_time;
    if (!input.keys.holdKey(.left_control)) speed *= 20;
    return speed;
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
    const cameraSpeed: @Vector(4, f32) = @splat(speed);
    const np = cp + cf * cameraSpeed;
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
    const cameraSpeed: @Vector(4, f32) = @splat(speed);
    const np = cp - cf * cameraSpeed;
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
    const cameraSpeed: @Vector(4, f32) = @splat(speed);
    const np = cp - zm.normalize3(zm.cross3(cf, cu)) * cameraSpeed;
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
    const cameraSpeed: @Vector(4, f32) = @splat(speed);
    const np = cp + zm.normalize3(zm.cross3(cf, cu)) * cameraSpeed;
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
    const cameraSpeed: @Vector(4, f32) = @splat(speed);
    const upDirection: @Vector(4, f32) = @splat(1.0);
    const np = cp + cu * cameraSpeed * upDirection;
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
    const cameraSpeed: @Vector(4, f32) = @splat(speed);
    const downDirection: @Vector(4, f32) = @splat(-1.0);
    const np = cp + cu * cameraSpeed * downDirection;
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
