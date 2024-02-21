const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const gl = @import("zopengl");
const tags = @import("../../tags.zig");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");

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
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const ers: []components.gfx.ElementsRenderer = ecs.field(it, components.gfx.ElementsRenderer, 1) orelse return;
            const er = ers[i];
            if (er.enableDepthTest) gl.enable(gl.DEPTH_TEST);
            gl.deleteProgram(er.program);
            gl.deleteVertexArrays(1, &er.vao);
            gl.deleteBuffers(1, &er.vbo);
            gl.deleteBuffers(1, &er.ebo);
            if (er.texture != 0) {
                gl.deleteTextures(1, &er.texture);
            }
            ecs.delete(game.state.world, entity);
        }
    }
}
