const system_name = "GfxSortedMultiDrawSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.gfx.ElementsRenderer) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.gfx.SortedMultiDraw) };
    desc.run = if (config.use_tracy) runWithTrace else run;
    return desc;
}

fn runWithTrace(it: *ecs.iter_t) callconv(.C) void {
    ztracy.Message(system_name);
    const tracy_zone = ztracy.ZoneNC(@src(), system_name, 0xff_00_ff_f0);
    defer tracy_zone.End();
    return run(it);
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    const screen: *const components.screen.Screen = ecs.get(
        world,
        game.state.entities.screen,
        components.screen.Screen,
    ) orelse return;
    if (!ecs.is_alive(world, screen.current)) {
        std.debug.print("current {d} is not alive!\n", .{screen.current});
        return;
    }
    const enableWireframe = ecs.has_id(world, screen.current, ecs.id(components.gfx.Wireframe));
    if (game.state.ui.gfx_wire_frames or enableWireframe) gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const ers: []components.gfx.ElementsRenderer = ecs.field(it, components.gfx.ElementsRenderer, 1) orelse continue;
            const er = ers[i];
            gfxSortedMultiDraw(world, entity, screen, er);
        }
    }
    if (game.state.ui.gfx_wire_frames or enableWireframe) gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
}

fn gfxSortedMultiDraw(
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

    game.state.ui.gfx_meshes_drawn_counter += 0;
    gl.multiDrawElements(gl.TRIANGLES, 0, gl.UNSIGNED_INT, 0, 0);
}

const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const gl = @import("zopengl").bindings;
const ztracy = @import("ztracy");
const config = @import("config");
const tags = @import("../../tags.zig");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const gfx = @import("../../../gfx/gfx.zig");