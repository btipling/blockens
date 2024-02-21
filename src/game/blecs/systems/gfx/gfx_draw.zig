const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const gl = @import("zopengl");
const tags = @import("../../tags.zig");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");

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
        game.state.world,
        game.state.entities.screen,
        components.screen.Screen,
    ) orelse unreachable;
    if (!ecs.is_alive(world, screen.current)) {
        std.debug.print("current {d} is not alive!\n", .{screen.current});
        return;
    }
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
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
            gl.drawElements(gl.TRIANGLES, er.numIndices, gl.UNSIGNED_INT, null);
        }
    }
}
