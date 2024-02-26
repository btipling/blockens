const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const math = @import("../../../math/math.zig");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities_screen.zig");
const game = @import("../../../game.zig");
const gfx = @import("../../../shape/gfx/gfx.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "ScreenCameraSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.Camera) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    const screen: *const components.screen.Screen = ecs.get(
        game.state.world,
        game.state.entities.screen,
        components.screen.Screen,
    ) orelse unreachable;
    if (!ecs.is_alive(world, screen.current)) return;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const parent = ecs.get_parent(world, entity);
            const c: []components.screen.Camera = ecs.field(it, components.screen.Camera, 1) orelse return;
            if (parent == screen.gameDataEntity) {
                if (!ecs.has_id(world, screen.current, ecs.id(components.screen.Game))) {
                    ecs.remove(world, entity, components.screen.Updated);
                    continue;
                }
            }
            if (parent == screen.settingDataEntity) {
                if (!ecs.has_id(world, screen.current, ecs.id(components.screen.Settings))) {
                    ecs.remove(world, entity, components.screen.Updated);
                    continue;
                }
            }
            const ubo = game.state.gfx.ubos.get(c[i].ubo) orelse {
                continue;
            };
            var camera_position: @Vector(4, gl.Float) = undefined;
            var camera_front: @Vector(4, gl.Float) = undefined;
            var up_direction: @Vector(4, gl.Float) = undefined;
            var pitch: gl.Float = 0;
            var yaw: gl.Float = 0;
            var fovy: gl.Float = 0;
            var aspect: gl.Float = 0;
            var near: gl.Float = 0;
            var far: gl.Float = 0;
            var post_perspective: ?@Vector(4, gl.Float) = null;
            if (ecs.get_id(world, entity, ecs.id(components.screen.CameraPosition))) |opaque_ptr| {
                const cp: *const components.screen.CameraPosition = @ptrCast(@alignCast(opaque_ptr));
                camera_position = cp.pos;
            } else unreachable;
            if (ecs.get_id(world, entity, ecs.id(components.screen.CameraFront))) |opaque_ptr| {
                const cf: *const components.screen.CameraFront = @ptrCast(@alignCast(opaque_ptr));
                camera_front = cf.front;
            } else unreachable;
            if (ecs.get_id(world, entity, ecs.id(components.screen.CameraRotation))) |opaque_ptr| {
                const cr: *const components.screen.CameraRotation = @ptrCast(@alignCast(opaque_ptr));
                pitch = cr.pitch;
                yaw = cr.yaw;
            } else unreachable;
            if (ecs.get_id(world, entity, ecs.id(components.screen.UpDirection))) |opaque_ptr| {
                const u: *const components.screen.UpDirection = @ptrCast(@alignCast(opaque_ptr));
                up_direction = u.up;
            } else unreachable;
            if (ecs.get_id(world, entity, ecs.id(components.screen.Perspective))) |opaque_ptr| {
                const p: *const components.screen.Perspective = @ptrCast(@alignCast(opaque_ptr));
                fovy = p.fovy;
                aspect = p.aspect;
                near = p.near;
                far = p.far;
            } else unreachable;
            if (ecs.has_id(world, entity, ecs.id(components.screen.PostPerspective))) {
                if (ecs.get_id(world, entity, ecs.id(components.screen.PostPerspective))) |opaque_ptr| {
                    const pp: *const components.screen.PostPerspective = @ptrCast(@alignCast(opaque_ptr));
                    post_perspective = pp.translation;
                } else unreachable;
            }
            const lookAt = zm.lookAtRh(
                camera_position,
                camera_position + camera_front,
                up_direction,
            );
            const ps = zm.perspectiveFovRh(fovy, aspect, near, far);
            var m = zm.mul(lookAt, ps);
            if (post_perspective) |pp| {
                m = zm.mul(m, zm.translationV(pp));
            }
            var mut_camera: *components.screen.Camera = ecs.get_mut(
                game.state.world,
                entity,
                components.screen.Camera,
            ) orelse continue;
            mut_camera.elapsedTime += it.delta_time;
            gfx.Gfx.updateUniformBufferObject(m, mut_camera.elapsedTime, ubo);
            ecs.remove(world, entity, components.screen.Updated);
        }
    }
}
