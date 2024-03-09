const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl").bindings;
const zm = @import("zmath");
const components = @import("../../components/components.zig");
const helpers = @import("../../helpers.zig");
const game = @import("../../../game.zig");
const math = @import("../../../math/math.zig");
const entities = @import("../../entities/entities.zig");
const gfx = @import("../../../gfx/gfx.zig");
const game_state = @import("../../../state/state.zig");
const chunk = @import("../../../chunk.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "BlockMeshRenderingSystem", ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.block.Chunk) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.block.NeedsMeshRendering) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const c: []components.block.Chunk = ecs.field(it, components.block.Chunk, 1) orelse return;
            ecs.remove(world, entity, components.block.NeedsMeshRendering);
            render_mesh(world, entity, c[i].loc);
            ecs.add(world, entity, components.block.NeedsInstanceRendering);
        }
    }
}

fn render_mesh(world: *ecs.world_t, entity: ecs.entity_t, loc: @Vector(4, gl.Float)) void {
    var c: *chunk.Chunk = game.state.gfx.mesh_data.get(entity) orelse return;
    var keys = c.meshes.keyIterator();
    const parent: ecs.entity_t = ecs.get_parent(world, entity);
    while (keys.next()) |_k| {
        const i: usize = _k.*;
        if (c.meshes.get(i)) |s| {
            const block_id: u8 = @intCast(c.data[i]);
            const p = chunk.getPositionAtIndexV(i);
            const mb_e = helpers.new_child(world, parent);
            _ = ecs.set(world, mb_e, components.shape.Shape, .{ .shape_type = .meshed_voxel });
            const cr_c = math.vecs.Vflx4.initBytes(0, 0, 0, 0);
            _ = ecs.set(world, mb_e, components.shape.Color, components.shape.Color.fromVec(cr_c));
            if (parent == entities.screen.game_data) {
                _ = ecs.set(world, mb_e, components.shape.UBO, .{ .binding_point = gfx.constants.GameUBOBindingPoint });
            } else {
                _ = ecs.set(world, mb_e, components.shape.UBO, .{ .binding_point = gfx.constants.SettingsUBOBindingPoint });
            }
            _ = ecs.set(world, mb_e, components.block.Block, .{
                .block_id = block_id,
            });
            _ = ecs.set(world, mb_e, components.shape.Translation, .{
                .translation = .{ -0.5, -0.5, -0.5, 0 },
            });
            _ = ecs.set(world, mb_e, components.screen.WorldLocation, .{
                .loc = .{ p[0] + loc[0], p[1] + loc[1], p[2] + loc[2], p[3] + loc[3] },
            });
            _ = ecs.set(world, mb_e, components.block.Meshscale, .{
                .scale = s,
            });
            // ecs.add(world, mb_e, components.Debug);
            ecs.add(world, mb_e, components.shape.NeedsSetup);
        }
    }
}
