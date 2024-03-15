const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const zm = @import("zmath");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const game_data = @import("../../../state.zig");
const screen_entity = @import("../../entities/entities_screen.zig");
const gfx = @import("../../../gfx/gfx.zig");
const chunk = @import("../../../chunk.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "GfxMultiDrawUpdateSystem", ecs.PreStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.gfx.ElementsRenderer) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.gfx.NeedsMultiDrawDataUpdate) };
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
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            ecs.remove(world, entity, components.gfx.NeedsMultiDrawDataUpdate);
            const ers: []components.gfx.ElementsRenderer = ecs.field(it, components.gfx.ElementsRenderer, 1) orelse continue;
            const er = ers[i];
            if (!ecs.has_id(world, entity, ecs.id(components.block.Chunk))) continue;
            const chunk_c: *const components.block.Chunk = ecs.get(
                game.state.world,
                entity,
                components.block.Chunk,
            ) orelse unreachable;
            const parent = ecs.get_parent(world, entity);
            var c: *chunk.Chunk = undefined;
            if (parent == screen.gameDataEntity) {
                c = game.state.gfx.game_chunks.get(chunk_c.wp) orelse continue;
            }
            if (parent == screen.settingDataEntity) {
                c = game.state.gfx.settings_chunks.get(chunk_c.wp) orelse continue;
            }
            var data = std.ArrayList(f32).initCapacity(
                game.state.allocator,
                c.elements.items.len * 16,
            ) catch unreachable;
            defer data.deinit();
            for (c.elements.items) |ce| {
                const r = zm.matToArr(ce.transform);
                data.appendSliceAssumeCapacity(&r);
            }
            gfx.Gfx.updateInstanceData(
                er.program,
                er.vao,
                c.vbo,
                data.items,
            );

            std.debug.print("updated {d} multi draw items\n", .{data.items.len});
        }
    }
}
