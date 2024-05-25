const system_name = "BlockMeshRenderingSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.block.Chunk) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.block.NeedsMeshRendering) };
    desc.run = if (config.use_tracy) runWithTrace else run;
    return desc;
}

fn runWithTrace(it: *ecs.iter_t) callconv(.C) void {
    ztracy.Message(system_name);
    const tracy_zone = ztracy.ZoneNC(@src(), system_name, 0xff_00_ff_f0);
    defer tracy_zone.End();
    return run(it);
}

var did_debug: bool = false;

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const c: []components.block.Chunk = ecs.field(it, components.block.Chunk, 1) orelse return;
            if (ecs.has_id(world, entity, ecs.id(components.gfx.HasPreviousRenderer))) continue;
            if (ecs.get(world, entity, components.gfx.ElementsRenderer)) |erc| {
                // clean up previously rendered chunk by creating a new entity to handle the deletion

                const parent: ecs.entity_t = ecs.get_parent(world, entity);
                const to_delete = helpers.new_child(world, parent);

                _ = ecs.set(world, to_delete, components.gfx.ElementsRenderer, erc.*);
                _ = ecs.set(world, to_delete, components.block.Chunk, c[i]);
                ecs.add(world, to_delete, components.gfx.IsPreviousRenderer);
                ecs.add(world, to_delete, components.block.UseMultiDraw);
                ecs.add(world, to_delete, components.gfx.CanDraw);

                _ = ecs.set(world, entity, components.gfx.HasPreviousRenderer, .{
                    .entity = to_delete,
                });
                ecs.remove(world, entity, components.gfx.ElementsRenderer);
            }
            ecs.remove(world, entity, components.block.NeedsMeshRendering);
            render_multidraw(world, entity, c[i].wp);
        }
    }
}

fn render_multidraw(world: *ecs.world_t, entity: ecs.entity_t, wp: chunk.worldPosition) void {
    var c: *chunk.Chunk = undefined;
    const parent: ecs.entity_t = ecs.get_parent(world, entity);
    if (parent == entities.screen.game_data) {
        c = game.state.blocks.game_chunks.get(wp) orelse return;
        _ = ecs.set(world, entity, components.shape.UBO, .{ .binding_point = gfx.constants.GameUBOBindingPoint });
    } else {
        _ = ecs.set(world, entity, components.shape.UBO, .{ .binding_point = gfx.constants.SettingsUBOBindingPoint });
        c = game.state.blocks.settings_chunks.get(wp) orelse return;
    }
    const cr_c = math.vecs.Vflx4.initBytes(0, 0, 0, 0);
    _ = ecs.set(world, entity, components.shape.Color, components.shape.Color.fromVec(cr_c));
    _ = ecs.set(world, entity, components.shape.Shape, .{ .shape_type = .multidraw_voxel });
    _ = ecs.set(world, entity, components.shape.Lighting, .{ .ssbo = gfx.constants.LightingBindingPoint });
    ecs.add(world, entity, components.block.UseTextureAtlas);
    ecs.add(world, entity, components.shape.NeedsSetup);
    if (!did_debug) {
        // ecs.add(world, entity, components.Debug);
        did_debug = true;
    }
}

const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../components/components.zig");
const helpers = @import("../../helpers.zig");
const game = @import("../../../game.zig");
const math = @import("../../../math/math.zig");
const entities = @import("../../entities/entities.zig");
const gfx = @import("../../../gfx/gfx.zig");
const game_state = @import("../../../state.zig");
const block = @import("../../../block/block.zig");
const chunk = block.chunk;
