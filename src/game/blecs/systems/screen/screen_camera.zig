const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const config = @import("config");
const math = @import("../../../math/math.zig");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const chunk = @import("../../../chunk.zig");
const gfx = @import("../../../gfx/gfx.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "ScreenCameraSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.Camera) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.screen.CurrentCamera) };
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
            const c: []components.screen.Camera = ecs.field(it, components.screen.Camera, 1) orelse continue;
            if (config.use_tracy) {
                const tracy_zone = ztracy.ZoneNC(@src(), "ScreenCameraSystem", 0x00_33_ff_f0);
                defer tracy_zone.End();
                screenCameraSystem(world, entity, it, parent, screen, c[i]);
            } else {
                screenCameraSystem(world, entity, it, parent, screen, c[i]);
            }
        }
    }
}

fn screenCameraSystem(
    world: *ecs.world_t,
    entity: ecs.entity_t,
    it: *ecs.iter_t,
    parent: ecs.entity_t,
    screen: *const components.screen.Screen,
    c: components.screen.Camera,
) void {
    if (parent == screen.gameDataEntity) {
        if (!ecs.has_id(world, screen.current, ecs.id(components.screen.Game))) {
            ecs.remove(world, entity, components.screen.Updated);
            return;
        }
    }
    if (parent == screen.settingDataEntity) {
        if (!ecs.has_id(world, screen.current, ecs.id(components.screen.Settings))) {
            ecs.remove(world, entity, components.screen.Updated);
            return;
        }
    }
    const ubo = game.state.gfx.ubos.get(c.ubo) orelse {
        return;
    };
    var camera_position: @Vector(4, f32) = undefined;
    var camera_front: @Vector(4, f32) = undefined;
    var up_direction: @Vector(4, f32) = undefined;
    var pitch: f32 = 0;
    var yaw: f32 = 0;
    var fovy: f32 = 0;
    var aspect: f32 = 0;
    var near: f32 = 0;
    var far: f32 = 0;
    var world_scale: ?@Vector(4, f32) = null;
    var world_rotation: ?@Vector(4, f32) = null;
    var world_translation: ?@Vector(4, f32) = null;
    var post_perspective: ?@Vector(4, f32) = null;
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
    if (ecs.has_id(world, entity, ecs.id(components.screen.WorldScale))) {
        if (ecs.get_id(world, entity, ecs.id(components.screen.WorldScale))) |opaque_ptr| {
            const ws: *const components.screen.WorldScale = @ptrCast(@alignCast(opaque_ptr));
            world_scale = ws.scale;
        } else unreachable;
    }
    if (ecs.has_id(world, entity, ecs.id(components.screen.WorldRotation))) {
        if (ecs.get_id(world, entity, ecs.id(components.screen.WorldRotation))) |opaque_ptr| {
            const wr: *const components.screen.WorldRotation = @ptrCast(@alignCast(opaque_ptr));
            world_rotation = wr.rotation;
        } else unreachable;
    }
    if (ecs.has_id(world, entity, ecs.id(components.screen.WorldTranslation))) {
        if (ecs.get_id(world, entity, ecs.id(components.screen.WorldTranslation))) |opaque_ptr| {
            const wt: *const components.screen.WorldTranslation = @ptrCast(@alignCast(opaque_ptr));
            world_translation = wt.translation;
        } else unreachable;
    }
    if (ecs.has_id(world, entity, ecs.id(components.screen.PostPerspective))) {
        if (ecs.get_id(world, entity, ecs.id(components.screen.PostPerspective))) |opaque_ptr| {
            const pp: *const components.screen.PostPerspective = @ptrCast(@alignCast(opaque_ptr));
            post_perspective = pp.translation;
        } else unreachable;
    }
    var m = zm.identity();
    if (world_scale) |s| {
        m = zm.mul(m, zm.scalingV(s));
    }
    if (world_rotation) |r| {
        m = zm.mul(m, zm.quatToMat(r));
    }
    if (world_translation) |t| {
        m = zm.mul(m, zm.translationV(t));
    }
    const lookAt = zm.lookAtRh(
        camera_position,
        camera_position + camera_front,
        up_direction,
    );
    const perspective = zm.perspectiveFovRh(fovy, aspect, near, far);
    cullChunks(camera_position, lookAt, perspective);
    m = zm.mul(m, lookAt);
    m = zm.mul(m, perspective);
    if (post_perspective) |pp| {
        m = zm.mul(m, zm.translationV(pp));
    }
    var mut_camera: *components.screen.Camera = ecs.get_mut(
        game.state.world,
        entity,
        components.screen.Camera,
    ) orelse return;
    mut_camera.elapsedTime += it.delta_time;
    gfx.Gfx.updateUniformBufferObject(
        m,
        mut_camera.elapsedTime,
        game.state.gfx.animations_running,
        game.state.ui.data.texture_atlas_num_blocks,
        ubo,
    );
    ecs.remove(world, entity, components.screen.Updated);
}

fn euclideanDistance(v1: @Vector(4, f32), v2: @Vector(4, f32)) f32 {
    const diff = v1 - v2;
    const diffSquared = diff * diff;
    const sumSquared = zm.dot4(diffSquared, @Vector(4, f32){ 1.0, 1.0, 1.0, 0.0 })[0];
    return std.math.sqrt(sumSquared);
}

fn cullChunks(camera_position: @Vector(4, f32), view: zm.Mat, perspective: zm.Mat) void {
    const world = game.state.world;
    var it = game.state.gfx.game_chunks.iterator();
    outer: while (it.next()) |e| {
        const wp: chunk.worldPosition = e.key_ptr.*;
        const c: *chunk.Chunk = e.value_ptr.*;
        const p = wp.vecFromWorldPosition();
        const loc: @Vector(4, f32) = .{
            p[0] * chunk.chunkDim,
            p[1] * chunk.chunkDim,
            p[2] * chunk.chunkDim,
            1,
        };
        const front_bot_l: @Vector(4, f32) = loc;
        const front_bot_r: @Vector(4, f32) = .{
            loc[0] + chunk.chunkDim,
            loc[1],
            loc[2],
            loc[3],
        };
        const front_top_l: @Vector(4, f32) = .{
            loc[0],
            loc[1] + chunk.chunkDim,
            loc[2],
            loc[3],
        };
        const front_top_r: @Vector(4, f32) = .{
            loc[0] + chunk.chunkDim,
            loc[1] + chunk.chunkDim,
            loc[2],
            loc[3],
        };
        const back_bot_l: @Vector(4, f32) = .{
            loc[0],
            loc[1],
            loc[2] + chunk.chunkDim,
            loc[3],
        };
        const back_bot_r: @Vector(4, f32) = .{
            loc[0] + chunk.chunkDim,
            loc[1],
            loc[2] + chunk.chunkDim,
            loc[3],
        };
        const back_top_l: @Vector(4, f32) = .{
            loc[0],
            loc[1] + chunk.chunkDim,
            loc[2] + chunk.chunkDim,
            loc[3],
        };
        const back_top_r: @Vector(4, f32) = .{
            loc[0] + chunk.chunkDim,
            loc[1] + chunk.chunkDim,
            loc[2] + chunk.chunkDim,
            loc[3],
        };
        const to_check: [8]@Vector(4, f32) = .{
            front_bot_l,
            front_bot_r,
            front_top_l,
            front_top_r,
            back_bot_l,
            back_bot_r,
            back_top_l,
            back_top_r,
        };
        for (to_check) |coordinates| {
            const distance_from_camera = euclideanDistance(camera_position, coordinates);
            if (distance_from_camera <= chunk.chunkDim) {
                const renderer_entity = ecs.get_target(
                    world,
                    c.entity,
                    entities.block.HasChunkRenderer,
                    0,
                );
                if (renderer_entity != 0 and ecs.is_alive(world, renderer_entity)) {
                    ecs.add(world, renderer_entity, components.gfx.CanDraw);
                }
                continue :outer;
            }
            const ca_s: @Vector(4, f32) = zm.mul(coordinates, view);
            const clip_space: @Vector(4, f32) = zm.mul(ca_s, perspective);
            if (-clip_space[3] <= clip_space[0] and clip_space[0] <= clip_space[3] and
                -clip_space[3] <= clip_space[1] and clip_space[1] <= clip_space[3] and
                -clip_space[3] <= clip_space[2] and clip_space[2] <= clip_space[3])
            {
                const renderer_entity = ecs.get_target(
                    world,
                    c.entity,
                    entities.block.HasChunkRenderer,
                    0,
                );
                if (renderer_entity != 0 and ecs.is_alive(world, renderer_entity)) {
                    ecs.add(world, renderer_entity, components.gfx.CanDraw);
                }
                continue :outer;
            }
        }
        const renderer_entity = ecs.get_target(
            world,
            c.entity,
            entities.block.HasChunkRenderer,
            0,
        );
        ecs.remove(world, renderer_entity, components.gfx.CanDraw);
    }
}
