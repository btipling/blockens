const std = @import("std");
const ecs = @import("zflecs");
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

            if (ecs.has_id(world, entity, ecs.id(components.block.UseMultiDraw))) {
                std.debug.print("use multi draw detected in render mesh.\n", .{});
                render_multidraw(world, entity, c[i].loc, c[i].wp);
            } else {
                render_mesh(world, entity, c[i].loc, c[i].wp);
            }
            ecs.add(world, entity, components.block.NeedsInstanceRendering);
        }
    }
}

fn render_mesh(world: *ecs.world_t, entity: ecs.entity_t, loc: @Vector(4, f32), wp: chunk.worldPosition) void {
    var c: *chunk.Chunk = undefined;
    const parent: ecs.entity_t = ecs.get_parent(world, entity);
    if (parent == entities.screen.game_data) {
        c = game.state.gfx.game_chunks.get(wp) orelse return;
    } else {
        c = game.state.gfx.settings_chunks.get(wp) orelse return;
    }
    var keys = c.meshes.keyIterator();
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

fn render_multidraw(world: *ecs.world_t, entity: ecs.entity_t, loc: @Vector(4, f32), wp: chunk.worldPosition) void {
    _ = loc;
    var c: *chunk.Chunk = undefined;
    // _ = game.state.gfx.mesh_data.remove(entity);
    const parent: ecs.entity_t = ecs.get_parent(world, entity);
    if (parent == entities.screen.game_data) {
        c = game.state.gfx.game_chunks.get(wp) orelse return;
    } else {
        c = game.state.gfx.settings_chunks.get(wp) orelse return;
    }

    var keys = c.meshes.keyIterator();
    while (keys.next()) |_k| {
        const i: usize = _k.*;
        if (c.meshes.get(i)) |s| {
            _ = s;
            // const mb_e = helpers.new_child(world, parent);
            //     var block_id: u8 = 0;
            //     block_id = @intCast(c.data[i]);
            //     if (block_id == 0) continue; // Some kind of one off bug somewhere?
            //     var blocks_map: *std.AutoHashMap(u8, *game_state.BlockInstance) = undefined;
            //     if (parent == entities.screen.game_data) {
            //         blocks_map = &game.state.gfx.game_blocks;
            //     } else {
            //         blocks_map = &game.state.gfx.settings_blocks;
            //     }
            //     if (!blocks_map.contains(block_id)) {
            //         const block_entity = helpers.new_child(world, parent);
            //         const bi: *game_state.BlockInstance = game.state.allocator.create(game_state.BlockInstance) catch unreachable;
            //         bi.* = .{
            //             .entity_id = block_entity,
            //             .transforms = std.ArrayList(zm.Mat).init(game.state.allocator),
            //         };
            //         blocks_map.put(block_id, bi) catch unreachable;
            //         ecs.add(world, bi.entity_id, components.block.Instance);
            //         _ = ecs.set(world, bi.entity_id, components.shape.Shape, .{ .shape_type = .cube });
            //         const cr_c = math.vecs.Vflx4.initBytes(0, 0, 0, 0);
            //         _ = ecs.set(world, bi.entity_id, components.shape.Color, components.shape.Color.fromVec(cr_c));
            // if (parent == entities.screen.game_data) {
            //     _ = ecs.set(world, bi.entity_id, components.shape.UBO, .{ .binding_point = gfx.constants.GameUBOBindingPoint });
            // } else {
            //     _ = ecs.set(world, bi.entity_id, components.shape.UBO, .{ .binding_point = gfx.constants.SettingsUBOBindingPoint });
            // }
            //         _ = ecs.set(world, bi.entity_id, components.block.Block, .{
            //             .block_id = block_id,
            //         });
            //         // ecs.add(game.state.world, bi.entity_id, components.Debug);
            //         ecs.add(world, bi.entity_id, components.shape.NeedsSetup);
            //     }
            //     const bi: *game_state.BlockInstance = blocks_map.get(block_id).?;
            //     ecs.add(world, bi.entity_id, components.gfx.NeedsInstanceDataUpdate);
            //     const p: @Vector(4, f32) = chunk.getPositionAtIndexV(i);
            //     const fp: @Vector(4, f32) = .{ p[0] + 0.5 + loc[0], p[1] + 0.5 + loc[1], p[2] + 0.5 + loc[2], p[3] + loc[3] };
            //     bi.transforms.append(zm.translationV(fp)) catch |e| {
            //         std.debug.print("got an error appending transforms? {}\n", .{e});
            //     };
        }
    }
    // if (parent == entities.screen.game_data) game.state.allocator.free(c.data);
    // c.deinit();
    // game.state.allocator.destroy(c);
}
