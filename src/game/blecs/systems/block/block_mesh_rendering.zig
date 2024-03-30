const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const components = @import("../../components/components.zig");
const helpers = @import("../../helpers.zig");
const game = @import("../../../game.zig");
const math = @import("../../../math/math.zig");
const entities = @import("../../entities/entities.zig");
const gfx = @import("../../../gfx/gfx.zig");
const game_state = @import("../../../state.zig");
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
            if (ecs.get(world, entity, components.gfx.ElementsRenderer)) |erc| {
                // clean up previously rendered chunk by creating a new entity to handle the deletion
                const to_delete = ecs.new_id(world);
                std.debug.print("deleting chunk rendering {}\n", .{to_delete});
                _ = ecs.set(world, to_delete, components.gfx.ElementsRenderer, erc.*);
                ecs.add(world, to_delete, components.gfx.NeedsDeletion);
                ecs.remove(world, entity, components.gfx.CanDraw);
                ecs.remove(world, entity, components.gfx.ElementsRenderer);
            }
            render_multidraw(world, entity, c[i].loc, c[i].wp);
            ecs.add(world, entity, components.block.NeedsInstanceRendering);
        }
    }
}

fn render_multidraw(world: *ecs.world_t, entity: ecs.entity_t, _: @Vector(4, f32), wp: chunk.worldPosition) void {
    var c: *chunk.Chunk = undefined;
    const parent: ecs.entity_t = ecs.get_parent(world, entity);
    if (parent == entities.screen.game_data) {
        c = game.state.gfx.game_chunks.get(wp) orelse return;
        _ = ecs.set(world, entity, components.shape.UBO, .{ .binding_point = gfx.constants.GameUBOBindingPoint });
    } else {
        _ = ecs.set(world, entity, components.shape.UBO, .{ .binding_point = gfx.constants.SettingsUBOBindingPoint });
        c = game.state.gfx.settings_chunks.get(wp) orelse return;
    }
    const cr_c = math.vecs.Vflx4.initBytes(0, 0, 0, 0);
    _ = ecs.set(world, entity, components.shape.Color, components.shape.Color.fromVec(cr_c));
    _ = ecs.set(world, entity, components.shape.Shape, .{ .shape_type = .multidraw_voxel });
    ecs.add(world, entity, components.block.UseTextureAtlas);
    ecs.add(world, entity, components.shape.NeedsSetup);
    // ecs.add(world, entity, components.Debug);
}
