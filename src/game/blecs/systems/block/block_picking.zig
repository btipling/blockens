const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const chunk = @import("../../../chunk.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "BlockPickingSystem", ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.mob.DidUpdate) };
    desc.run = run;
    return desc;
}

var current_block_id: u8 = 0;

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        outer: for (0..it.count()) |_| {
            const entity = game.state.entities.third_person_camera;
            if (!ecs.has_id(world, entity, ecs.id(components.screen.CurrentCamera))) continue;
            const cp: *const components.screen.CameraPosition = ecs.get(
                game.state.world,
                entity,
                components.screen.CameraPosition,
            ) orelse continue;
            const cf: *const components.screen.CameraFront = ecs.get(
                game.state.world,
                entity,
                components.screen.CameraFront,
            ) orelse continue;
            const camera_pos: @Vector(4, f32) = cp.pos;
            const ray_direction = zm.normalize3(cf.front);
            const step_size: f32 = 0.01;
            const max_distance: f32 = 100;
            var i: f32 = 5;
            while (i < max_distance) : (i += step_size) {
                const distance: @Vector(4, f32) = @splat(i);
                const pos: @Vector(4, f32) = camera_pos + ray_direction * distance;
                const block_id = chunk.getBlockId(pos);
                if (block_id != 0) {
                    const blh_e = game.state.entities.block_highlight;
                    var block_pos: @Vector(4, f32) = @floor(pos);
                    block_pos[3] = 0;
                    const wl = ecs.get_mut(
                        world,
                        blh_e,
                        components.screen.WorldLocation,
                    ) orelse continue :outer;
                    if (@reduce(.And, wl.loc == block_pos)) {
                        continue :outer;
                    }
                    var og_pos = wl.loc;
                    og_pos[3] = 0;
                    wl.loc = block_pos;
                    ecs.add(world, blh_e, components.gfx.NeedsUniformUpdate);
                    continue :outer;
                }
            }
        }
    }
}
