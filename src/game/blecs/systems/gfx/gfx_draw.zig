const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const gl = @import("zopengl").bindings;
const tags = @import("../../tags.zig");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const chunk = @import("../../../chunk.zig");
const game_state = @import("../../../state.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "GfxDrawSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.gfx.ElementsRenderer) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.gfx.CanDraw) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    const screen: *const components.screen.Screen = ecs.get(
        world,
        game.state.entities.screen,
        components.screen.Screen,
    ) orelse unreachable;
    if (!ecs.is_alive(world, screen.current)) {
        std.debug.print("current {d} is not alive!\n", .{screen.current});
        return;
    }
    const enableWireframe = ecs.has_id(world, screen.current, ecs.id(components.gfx.Wireframe));
    if (enableWireframe) gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            if (!ecs.is_alive(world, entity)) continue;
            if (ecs.has_id(world, entity, ecs.id(components.gfx.ManuallyHidden))) continue;
            const parent = ecs.get_parent(world, entity);
            if (parent == screen.gameDataEntity) {
                if (!ecs.has_id(world, screen.current, ecs.id(components.screen.Game))) {
                    continue;
                }
            }
            if (parent == screen.settingDataEntity) {
                if (!ecs.has_id(world, screen.current, ecs.id(components.screen.Settings))) {
                    continue;
                }
            }
            const ers: []components.gfx.ElementsRenderer = ecs.field(it, components.gfx.ElementsRenderer, 1) orelse return;
            const er = ers[i];
            if (er.enableDepthTest) gl.enable(gl.DEPTH_TEST);
            gl.useProgram(er.program);
            if (er.texture != 0) {
                gl.activeTexture(gl.TEXTURE0);
                gl.bindTexture(gl.TEXTURE_2D, er.texture);
            }
            gl.bindVertexArray(er.vao);
            const has_instance = ecs.has_id(world, entity, ecs.id(components.block.Instance));
            const use_multidraw = ecs.has_id(world, entity, ecs.id(components.block.UseMultiDraw));
            if (!has_instance and !use_multidraw) {
                gl.drawElements(gl.TRIANGLES, er.numIndices, gl.UNSIGNED_INT, null);
                continue;
            }
            if (has_instance) {
                // draw instances
                const block: ?*const components.block.Block = ecs.get(world, entity, components.block.Block);
                if (block == null) continue;
                var block_instance: ?*game_state.BlockInstance = null;
                if (parent == screen.gameDataEntity) {
                    block_instance = game.state.gfx.game_blocks.get(block.?.block_id);
                }
                if (parent == screen.settingDataEntity) {
                    block_instance = game.state.gfx.settings_blocks.get(block.?.block_id);
                }
                if (block_instance == null) continue;
                if (block_instance.?.transforms.items.len < 1) continue;
                gl.drawElementsInstanced(
                    gl.TRIANGLES,
                    er.numIndices,
                    gl.UNSIGNED_INT,
                    null,
                    @intCast(block_instance.?.transforms.items.len),
                );
            }
            if (use_multidraw) {
                const chunk_c: ?*const components.block.Chunk = ecs.get(world, entity, components.block.Chunk);
                if (chunk_c == null) continue;
                var c: *chunk.Chunk = undefined;
                if (parent == screen.gameDataEntity) {
                    if (game.state.gfx.game_chunks.get(chunk_c.?.wp)) |c_| {
                        c = c_;
                    } else {
                        continue;
                    }
                }
                if (parent == screen.settingDataEntity) {
                    if (game.state.gfx.settings_chunks.get(chunk_c.?.wp)) |c_| {
                        c = c_;
                    } else {
                        continue;
                    }
                }
                if (c.draws) |d| {
                    gl.multiDrawElements(gl.TRIANGLES, d.ptr, gl.UNSIGNED_INT, @ptrCast(c.draw_offsets_gl.?.ptr), @intCast(d.len));
                }
            }
        }
    }
    if (enableWireframe) gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
}
