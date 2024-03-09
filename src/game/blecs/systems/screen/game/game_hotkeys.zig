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
            if (input.keys.holdKey(.w)) goForward();
            if (input.keys.holdKey(.s)) goBack();
            if (input.keys.holdKey(.a)) goLeft();
            if (input.keys.holdKey(.d)) goRight();
            if (input.keys.holdKey(.space)) goUp();
            if (input.keys.holdKey(.left_shift)) goDown();
            if (input.keys.holdKey(.F3)) {
                ecs.add(game.state.world, game.state.entities.ui, components.ui.Menu);
                pressedKeyState = .F3;
            } else {
                if (pressedKeyState) |k| {
                    switch (k) {
                        .F3 => {
                            ecs.remove(game.state.world, game.state.entities.ui, components.ui.Menu);
                            pressedKeyState = null;
                        },
                        else => {},
                    }
                }
            }
        }
    }
}

fn getSpeed() f32 {
    var speed = 2.5 * game.state.input.delta_time;
    if (!input.keys.holdKey(.left_control)) speed *= 20;
    return speed;
}

fn goForward() void {
    const camera_front: *const components.screen.CameraFront = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.CameraFront,
    ) orelse return;
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.game_camera,
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

fn goBack() void {
    const camera_front: *const components.screen.CameraFront = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.CameraFront,
    ) orelse return;
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.game_camera,
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

fn goLeft() void {
    const camera_front: *const components.screen.CameraFront = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.CameraFront,
    ) orelse return;
    const camera_up: *const components.screen.UpDirection = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.UpDirection,
    ) orelse return;
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.game_camera,
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

fn goRight() void {
    const camera_front: *const components.screen.CameraFront = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.CameraFront,
    ) orelse return;
    const camera_up: *const components.screen.UpDirection = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.UpDirection,
    ) orelse return;
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.game_camera,
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

fn goUp() void {
    const camera_up: *const components.screen.UpDirection = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.UpDirection,
    ) orelse return;
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.game_camera,
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

fn goDown() void {
    const camera_up: *const components.screen.UpDirection = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.UpDirection,
    ) orelse return;
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.game_camera,
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
        game.state.entities.game_camera,
        components.screen.Updated,
    );
}
