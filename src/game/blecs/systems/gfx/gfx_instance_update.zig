const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const tags = @import("../../tags.zig");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const game_data = @import("../../../state/game.zig");
const screen_entity = @import("../../entities/entities_screen.zig");
const gfx = @import("../../../shape/gfx/gfx.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "GfxInstanceUpdateSystem", ecs.PreStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.gfx.ElementsRenderer) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.gfx.NeedsInstanceDataUpdate) };
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
            ecs.remove(world, entity, components.gfx.NeedsInstanceDataUpdate);
            const ers: []components.gfx.ElementsRenderer = ecs.field(it, components.gfx.ElementsRenderer, 1) orelse return;
            const er = ers[i];
            if (ecs.has_id(world, entity, ecs.id(components.block.BlockInstance))) continue;
            const block: *const components.block.Block = ecs.get(
                game.state.world,
                entity,
                components.block.Block,
            ) orelse unreachable;
            std.debug.print("gfx_instance_update_00\n", .{});
            const parent = ecs.get_parent(world, entity);
            var block_instance: ?*game_data.BlockInstance = null;
            if (parent == screen.gameDataEntity and game.state.gfx.game_blocks.contains(block.block_id)) {
                block_instance = game.state.gfx.game_blocks.get(block.block_id);
            }
            if (parent == screen.settingDataEntity and game.state.gfx.settings_blocks.contains(block.block_id)) {
                block_instance = game.state.gfx.settings_blocks.get(block.block_id);
            }
            std.debug.print("gfx_instance_update_01\n", .{});
            if (block_instance == null) continue;
            std.debug.print("gfx_instance_update_02\n", .{});
            var data = std.ArrayList(gl.Float).initCapacity(
                game.state.allocator,
                block_instance.?.transforms.items.len * 16,
            ) catch unreachable;
            std.debug.print("gfx_instance_update_03\n", .{});
            defer data.deinit();
            for (block_instance.?.transforms.items) |m| {
                const r = zm.matToArr(m);
                data.appendSliceAssumeCapacity(&r);
            }
            std.debug.print("gfx_instance_update_04\n", .{});
            gfx.Gfx.updateInstanceData(
                er.program,
                er.vao,
                block_instance.?.vbo,
                data.items,
            );
            std.debug.print("uh updated {d} num instance items?\n", .{data.items.len});
        }
    }
}
