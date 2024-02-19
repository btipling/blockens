const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const gl = @import("zopengl");
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
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.Updated) };
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
            const ubo = game.state.gfx.ubos.get(entities.GameUBOBindingPoint) orelse {
                std.debug.print("no ubo yet\n", .{});
                continue;
            };
            var camera_position: math.vecs.Vflx4 = undefined;
            var camera_front: math.vecs.Vflx4 = undefined;
            var up_direction: math.vecs.Vflx4 = undefined;
            var pitch: gl.Float = 0;
            var yaw: gl.Float = 0;
            var fovy: gl.Float = 0;
            var aspect: gl.Float = 0;
            var near: gl.Float = 0;
            var far: gl.Float = 0;
            if (ecs.get_id(world, entity, ecs.id(components.screen.CameraPosition))) |opaque_ptr| {
                const cp: *const components.screen.CameraPosition = @ptrCast(@alignCast(opaque_ptr));
                camera_position = cp.toVec();
            } else unreachable;
            if (ecs.get_id(world, entity, ecs.id(components.screen.CameraFront))) |opaque_ptr| {
                const cf: *const components.screen.CameraFront = @ptrCast(@alignCast(opaque_ptr));
                camera_front = cf.toVec();
            } else unreachable;
            if (ecs.get_id(world, entity, ecs.id(components.screen.CameraRotation))) |opaque_ptr| {
                const cr: *const components.screen.CameraRotation = @ptrCast(@alignCast(opaque_ptr));
                pitch = cr.pitch;
                yaw = cr.yaw;
            } else unreachable;
            if (ecs.get_id(world, entity, ecs.id(components.screen.UpDirection))) |opaque_ptr| {
                const u: *const components.screen.UpDirection = @ptrCast(@alignCast(opaque_ptr));
                up_direction = u.toVec();
            } else unreachable;
            if (ecs.get_id(world, entity, ecs.id(components.screen.Perspective))) |opaque_ptr| {
                const p: *const components.screen.Perspective = @ptrCast(@alignCast(opaque_ptr));
                fovy = p.fovy;
                aspect = p.aspect;
                near = p.near;
                far = p.far;
            } else unreachable;
            const lookAt = zm.lookAtRh(
                camera_position.value,
                camera_position.value + camera_front.value,
                up_direction.value,
            );
            const ps = zm.perspectiveFovRh(fovy, aspect, near, far);
            gfx.Gfx.updateUniformBufferObject(zm.mul(ps, lookAt), ubo);
            std.debug.print("doing camera updated\n", .{});
            std.debug.print("camera pos: ({d}, {d}, {d})\n", .{
                camera_position.value[0],
                camera_position.value[1],
                camera_position.value[2],
            });
            std.debug.print("camera rot: pitch: {d} yaw: {d}\n", .{
                pitch,
                yaw,
            });
            ecs.remove(world, entity, components.screen.Updated);
        }
    }
}
