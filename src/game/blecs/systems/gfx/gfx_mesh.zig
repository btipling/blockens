const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const zm = @import("zmath");
const gl = @import("zopengl");
const tags = @import("../../tags.zig");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const game_state = @import("../../../state/game.zig");
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
            const erc = ers[i];
            const er: *game_state.ElementsRendererConfig = game.state.gfx.renderConfigs.get(erc.id) orelse {
                std.debug.print("couldn't find render config for {d}\n", .{erc.id});
                continue;
            };
            const vertexShader: [:0]const u8 = er.vertexShader;
            const fragmentShader: [:0]const u8 = er.fragmentShader;
            const positions: [][3]gl.Float = er.positions;
            const indices: []gl.Uint = er.indices;
            const texcoords: ?[][2]gl.Float = er.texcoords;
            const normals: ?[][3]gl.Float = er.normals;
            defer game.state.allocator.free(vertexShader);
            defer game.state.allocator.free(fragmentShader);
            defer game.state.allocator.free(positions);
            defer game.state.allocator.free(indices);
            defer if (texcoords) |t| game.state.allocator.free(t);
            defer if (normals) |n| game.state.allocator.free(n);
            defer _ = game.state.gfx.renderConfigs.remove(erc.id);
            defer game.state.allocator.destroy(er);
            defer ecs.delete(world, erc.id);

            const vao = gfx.Gfx.initVAO() catch unreachable;
            const vbo = gfx.Gfx.initVBO() catch unreachable;
            const ebo = gfx.Gfx.initEBO(indices) catch unreachable;
            const vs = gfx.Gfx.initVertexShader(vertexShader) catch unreachable;
            const fs = gfx.Gfx.initFragmentShader(fragmentShader) catch unreachable;
            const program = gfx.Gfx.initProgram(&[_]gl.Uint{ vs, fs }) catch unreachable;
            gl.useProgram(program);
            gfx.Gfx.addVertexAttribute([3]gl.Float, positions.ptr, @intCast(positions.len));

            if (er.transform) |t| {
                gfx.Gfx.setUniformMat(shadergen.TransformMatName, program, t);
            }

            if (er.ubo_binding_point) |ubo_binding_point| {
                var ubo: gl.Uint = 0;
                ubo = game.state.gfx.ubos.get(ubo_binding_point) orelse blk: {
                    const m = zm.identity();
                    const new_ubo = gfx.Gfx.initUniformBufferObject(m);
                    game.state.gfx.ubos.put(ubo_binding_point, new_ubo) catch unreachable;
                    break :blk new_ubo;
                };
                gfx.Gfx.setUniformBufferObject(shadergen.UBOName, program, ubo, ubo_binding_point);
            }

            var texture: gl.Uint = 0;
            if (er.has_demo_cube_texture) {
                if (game.state.ui.data.texture_rgba_data) |d| {
                    texture = gfx.Gfx.initTextureFromColors(d);
                }
            }

            ecs.remove(it.world, entity, components.gfx.ElementsRendererConfig);
            _ = ecs.set(world, entity, components.gfx.ElementsRenderer, .{
                .program = program,
                .vao = vao,
                .vbo = vbo,
                .ebo = ebo,
                .texture = texture,
                .numIndices = @intCast(er.indices.len),
            });
            _ = ecs.add(world, entity, components.gfx.CanDraw);
        }
    }
}
