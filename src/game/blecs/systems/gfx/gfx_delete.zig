const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const gl = @import("zopengl").bindings;
const tags = @import("../../tags.zig");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const screen_entity = @import("../../entities/entities_screen.zig");
const gfx = @import("../../../gfx/gfx.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "GfxDeleteSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.gfx.ElementsRenderer) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.gfx.NeedsDeletion) };
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

            ecs.remove(world, entity, components.gfx.NeedsDeletion);
            const ers: []components.gfx.ElementsRenderer = ecs.field(it, components.gfx.ElementsRenderer, 1) orelse continue;
            const er = ers[i];
            if (ecs.has_id(world, entity, ecs.id(components.block.Instance))) {
                const block: *const components.block.Block = ecs.get(
                    game.state.world,
                    entity,
                    components.block.Block,
                ) orelse unreachable;
                // Instances aren't deleted, we just drop drawing them and delete their transforms.
                ecs.remove(world, entity, components.gfx.CanDraw);
                const parent = ecs.get_parent(world, entity);
                if (parent == screen.gameDataEntity and game.state.gfx.game_blocks.contains(block.block_id)) {
                    game.state.gfx.game_blocks.get(block.block_id).?.transforms.clearAndFree();
                }
                if (parent == screen.settingDataEntity and game.state.gfx.settings_blocks.contains(block.block_id)) {
                    game.state.gfx.settings_blocks.get(block.block_id).?.transforms.clearAndFree();
                }
                continue;
            }
            gl.deleteProgram(er.program);
            gl.deleteVertexArrays(1, &er.vao);
            gl.deleteBuffers(1, &er.vbo);
            gl.deleteBuffers(1, &er.ebo);
            if (er.texture != 0) {
                if (gfx.gl.atlas_texture) |at| {
                    if (er.texture != at) gl.deleteTextures(1, &er.texture);
                } else {
                    gl.deleteTextures(1, &er.texture);
                }
            }
            ecs.delete(game.state.world, entity);
        }
    }
}
