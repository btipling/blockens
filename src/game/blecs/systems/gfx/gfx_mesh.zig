const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const zm = @import("zmath");
const gl = @import("zopengl");
const tags = @import("../../tags.zig");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const gfx = @import("../../../shape/gfx/gfx.zig");
const shadergen = @import("../../../shape/gfx/shadergen.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "GfxMeshSystem", ecs.OnUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.gfx.ElementsRendererConfig) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        const world = it.world;
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const ers: []components.gfx.ElementsRendererConfig = ecs.field(it, components.gfx.ElementsRendererConfig, 1) orelse return;
            const er = ers[i];

            defer game.state.allocator.free(er.vertexShader);
            defer game.state.allocator.free(er.fragmentShader);
            defer game.state.allocator.free(er.positions);
            defer game.state.allocator.free(er.indices);

            const vao = gfx.Gfx.initVAO() catch unreachable;
            const vbo = gfx.Gfx.initVBO() catch unreachable;
            const ebo = gfx.Gfx.initEBO(er.indices) catch unreachable;
            const vs = gfx.Gfx.initVertexShader(er.vertexShader) catch unreachable;
            const fs = gfx.Gfx.initFragmentShader(er.fragmentShader) catch unreachable;
            const program = gfx.Gfx.initProgram(&[_]gl.Uint{ vs, fs }) catch unreachable;
            gl.useProgram(program);
            gfx.Gfx.addVertexAttribute([3]gl.Float, er.positions.ptr, @intCast(er.positions.len)) catch unreachable;

            if (er.transform) |t| {
                gfx.Gfx.setUniformMat(shadergen.TransformMatName, program, t) catch unreachable;
            }

            ecs.remove(it.world, entity, components.gfx.ElementsRendererConfig);
            _ = ecs.set(world, entity, components.gfx.ElementsRenderer, .{
                .program = program,
                .vao = vao,
                .vbo = vbo,
                .ebo = ebo,
                .numIndices = @intCast(er.indices.len),
            });
            _ = ecs.add(world, entity, components.gfx.CanDraw);
        }
    }
}
