const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl").bindings;
const components = @import("../../components/components.zig");
const helpers = @import("../../helpers.zig");
const game = @import("../../../game.zig");
const game_state = @import("../../../state/game.zig");
const cltf_mesh = @import("../../../shape/gfx/cltf_mesh.zig");
const gfx = @import("../../../shape/gfx/gfx.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "MobSetupSystem", ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.mob.Mob) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.mob.NeedsSetup) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const m: []components.mob.Mob = ecs.field(it, components.mob.Mob, 1) orelse return;
            ecs.remove(world, entity, components.mob.NeedsSetup);
            setupMob(world, entity, m[i].mob_id, m[i].data_entity) catch unreachable;
        }
    }
}

fn setupMob(world: *ecs.world_t, entity: ecs.entity_t, mob_id: i32, data_entity: ecs.entity_t) !void {
    if (game.state.gfx.mob_data.get(mob_id) == null) {
        var cm = cltf_mesh.Mesh.init(mob_id) catch unreachable;
        defer cm.deinit();
        cm.build() catch unreachable;
    }

    const mob = game.state.gfx.mob_data.get(mob_id).?;
    for (mob.meshes.items, 0..) |mesh, mesh_id| {
        const c_m = helpers.new_child(world, data_entity);
        _ = ecs.set(world, c_m, components.shape.Shape, .{ .shape_type = .mob });
        _ = ecs.set(world, c_m, components.mob.Mesh, .{
            .mesh_id = mesh_id,
            .mob_entity = entity,
        });
        {
            // TODO: add position
            _ = ecs.set(
                world,
                c_m,
                components.shape.Translation,
                .{ .translation = game.state.ui.data.demo_cube_translation },
            );
            _ = ecs.set(world, c_m, components.shape.UBO, .{ .binding_point = gfx.bindings.SettingsUBOBindingPoint });
        }

        if (mesh.animations != null and mesh.animations.?.items.len > 0) {
            _ = ecs.set(
                world,
                c_m,
                components.gfx.AnimationSSBO,
                // TODO: build a better ssbo so I don't add the mesh_id to the character binding point:
                .{ .ssbo = gfx.bindings.CharacterAnimationBindingPoint + @as(gl.Uint, @intCast(mesh_id)) },
            );
        }
        // ecs.add(world, c_m, components.Debug);
        ecs.add(world, c_m, components.shape.NeedsSetup);
    }
}
