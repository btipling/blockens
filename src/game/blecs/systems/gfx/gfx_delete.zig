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
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];

            ecs.remove(world, entity, components.gfx.NeedsDeletion);
            const ers: []components.gfx.ElementsRenderer = ecs.field(it, components.gfx.ElementsRenderer, 1) orelse continue;
            const er = ers[i];
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
