const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
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
    const menu: *components.ui.Menu = ecs.get_mut(
        game.state.world,
        game.state.entities.menu,
        components.ui.Menu,
    ) orelse unreachable;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            if (input.keys.holdKey(.w)) {
                goForward();
            }
            if (input.keys.holdKey(.s)) {
                goBack();
            }
            if (input.keys.holdKey(.a)) {
                goLeft();
            }
            if (input.keys.holdKey(.d)) {
                goRight();
            }
            if (input.keys.holdKey(.space)) {
                goUp();
            }
            if (input.keys.holdKey(.left_shift)) {
                goDown();
            }
            if (input.keys.holdKey(.F3)) {
                menu.visible = true;
                pressedKeyState = .F3;
            } else {
                if (pressedKeyState) |k| {
                    switch (k) {
                        .F3 => {
                            menu.visible = false;
                            pressedKeyState = null;
                        },
                        else => {},
                    }
                }
            }
        }
    }
}

fn getSpeed() gl.Float {
    var speed = 2.5 * game.state.input.delta_time;
    if (!input.keys.holdKey(.left_control)) {
        speed *= 2;
    }
    return speed;
}

fn goForward() void {
    const camera_front: *const components.screen.CameraFront = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.CameraFront,
    ) orelse {
        return;
    };
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.CameraPosition,
    ) orelse {
        return;
    };
    const cf = camera_front.front;
    const cp = camera_pos.toVec();
    const speed = getSpeed();
    const cameraSpeed: @Vector(4, gl.Float) = @splat(speed);
    const np = cp.value + cf * cameraSpeed;
    updateConditionally(camera_pos, np, cp.value);
}

fn goBack() void {
    const camera_front: *const components.screen.CameraFront = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.CameraFront,
    ) orelse {
        return;
    };
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.CameraPosition,
    ) orelse {
        return;
    };
    const cf = camera_front.front;
    const cp = camera_pos.toVec();
    const speed = getSpeed();
    const cameraSpeed: @Vector(4, gl.Float) = @splat(speed);
    const np = cp.value - cf * cameraSpeed;
    updateConditionally(camera_pos, np, cp.value);
}

fn goLeft() void {
    const camera_front: *const components.screen.CameraFront = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.CameraFront,
    ) orelse {
        return;
    };
    const camera_up: *const components.screen.UpDirection = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.UpDirection,
    ) orelse {
        return;
    };
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.CameraPosition,
    ) orelse {
        return;
    };
    const cf = camera_front.front;
    const cu = camera_up.toVec();
    const cp = camera_pos.toVec();
    const speed = getSpeed();
    const cameraSpeed: @Vector(4, gl.Float) = @splat(speed);
    const np = cp.value - zm.normalize3(zm.cross3(cf, cu.value)) * cameraSpeed;
    updateConditionally(camera_pos, np, cp.value);
}

fn goRight() void {
    const camera_front: *const components.screen.CameraFront = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.CameraFront,
    ) orelse {
        return;
    };
    const camera_up: *const components.screen.UpDirection = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.UpDirection,
    ) orelse {
        return;
    };
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.CameraPosition,
    ) orelse {
        return;
    };
    const cf = camera_front.front;
    const cu = camera_up.toVec();
    const cp = camera_pos.toVec();
    const speed = getSpeed();
    const cameraSpeed: @Vector(4, gl.Float) = @splat(speed);
    const np = cp.value + zm.normalize3(zm.cross3(cf, cu.value)) * cameraSpeed;
    updateConditionally(camera_pos, np, cp.value);
}

fn goUp() void {
    std.debug.print("going up?\n", .{});
    const camera_up: *const components.screen.UpDirection = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.UpDirection,
    ) orelse {
        std.debug.print("not going up?\n", .{});
        return;
    };
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.CameraPosition,
    ) orelse {
        std.debug.print("not going up?\n", .{});
        return;
    };
    const cu = camera_up.toVec();
    const cp = camera_pos.toVec();
    const speed = getSpeed();
    const cameraSpeed: @Vector(4, gl.Float) = @splat(speed);
    const upDirection: @Vector(4, gl.Float) = @splat(1.0);
    const np = cp.value + cu.value * cameraSpeed * upDirection;
    std.debug.print("going up???\n", .{});
    updateConditionally(camera_pos, np, cp.value);
}

fn goDown() void {
    const camera_up: *const components.screen.UpDirection = ecs.get(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.UpDirection,
    ) orelse {
        return;
    };
    var camera_pos: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.CameraPosition,
    ) orelse {
        return;
    };
    const cu = camera_up.toVec();
    const cp = camera_pos.toVec();
    const speed = getSpeed();
    const cameraSpeed: @Vector(4, gl.Float) = @splat(speed);
    const downDirection: @Vector(4, gl.Float) = @splat(-1.0);
    const np = cp.value + cu.value * cameraSpeed * downDirection;
    updateConditionally(camera_pos, np, cp.value);
}

fn updateConditionally(camera_pos: *components.screen.CameraPosition, np: [4]gl.Float, cp: [4]gl.Float) void {
    if (std.mem.eql(gl.Float, &np, &cp)) {
        std.debug.print("not updating from key pos.\n", .{});
        return;
    }
    camera_pos.x = np[0];
    camera_pos.y = np[1];
    camera_pos.z = np[2];
    camera_pos.w = np[3];
    ecs.add(
        game.state.world,
        game.state.entities.game_camera,
        components.screen.Updated,
    );
}
