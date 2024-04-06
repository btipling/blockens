const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const gl = @import("zopengl").bindings;
const ztracy = @import("ztracy");
const config = @import("config");
const tags = @import("../../tags.zig");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const chunk = @import("../../../chunk.zig");
const gfx = @import("../../../gfx/gfx.zig");

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
            const ers: []components.gfx.ElementsRenderer = ecs.field(it, components.gfx.ElementsRenderer, 1) orelse continue;
            const er = ers[i];
            if (config.use_tracy) {
                const tracy_zone = ztracy.ZoneNC(@src(), "GfxDrawSystem", 0x00_83_ff_f8);
                defer tracy_zone.End();
                gfxDraw(world, entity, screen, er);
            } else {
                gfxDraw(world, entity, screen, er);
            }
        }
    }
    if (enableWireframe) gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
}

fn gfxDraw(
    world: *ecs.world_t,
    entity: ecs.entity_t,
    screen: *const components.screen.Screen,
    er: components.gfx.ElementsRenderer,
) void {
    if (!ecs.is_alive(world, entity)) return;
    if (ecs.has_id(world, entity, ecs.id(components.gfx.ManuallyHidden))) return;
    const parent = ecs.get_parent(world, entity);
    if (parent == screen.gameDataEntity) {
        if (!ecs.has_id(world, screen.current, ecs.id(components.screen.Game))) {
            return;
        }
    }
    if (parent == screen.settingDataEntity) {
        if (!ecs.has_id(world, screen.current, ecs.id(components.screen.Settings))) {
            return;
        }
    }
    if (er.enableDepthTest) gl.enable(gl.DEPTH_TEST);
    gl.useProgram(er.program);
    if (er.texture != 0) {
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, er.texture);
    }
    gl.bindVertexArray(er.vao);
    const use_multidraw = ecs.has_id(world, entity, ecs.id(components.block.UseMultiDraw));
    if (!use_multidraw) {
        gl.drawElements(gl.TRIANGLES, er.numIndices, gl.UNSIGNED_INT, null);
        return;
    }
    if (use_multidraw) {
        const chunk_c: ?*const components.block.Chunk = ecs.get(world, entity, components.block.Chunk);
        if (chunk_c == null) return;
        var c: *chunk.Chunk = undefined;
        if (parent == screen.gameDataEntity) {
            if (game.state.blocks.game_chunks.get(chunk_c.?.wp)) |c_| {
                c = c_;
            } else {
                return;
            }
        }
        if (parent == screen.settingDataEntity) {
            if (game.state.blocks.settings_chunks.get(chunk_c.?.wp)) |c_| {
                c = c_;
            } else {
                return;
            }
        }
        c.mutex.lock();
        defer c.mutex.unlock();
        var offsets = c.prev_draw_offsets_gl;
        if (offsets == null) {
            offsets = c.draw_offsets_gl;
        }
        if (offsets == null) {
            return;
        }
        var draws = c.prev_draws;
        if (draws == null) {
            draws = c.draws;
        }
        if (draws) |d| {
            gl.multiDrawElements(gl.TRIANGLES, d.ptr, gl.UNSIGNED_INT, @ptrCast(offsets.?.ptr), @intCast(d.len));
        } else {
            std.debug.print("cant draw the thing\n", .{});
        }

        if (ecs.has_id(world, entity, ecs.id(components.gfx.HasPreviousRenderer))) {
            if (config.use_tracy) ztracy.MessageC("deleting previous render", 0xFFFF00);
            const pr = ecs.get(
                world,
                entity,
                components.gfx.HasPreviousRenderer,
            ) orelse @panic("nope");
            ecs.remove(world, pr.entity, components.gfx.CanDraw);
            ecs.add(world, pr.entity, components.gfx.NeedsDeletion);
            ecs.remove(world, entity, components.gfx.HasPreviousRenderer);
            c.deinitRenderPreviousData();
        }
    }
}
