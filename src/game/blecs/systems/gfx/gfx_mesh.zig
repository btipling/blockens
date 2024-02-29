const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
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
    const screen: *const components.screen.Screen = ecs.get(
        game.state.world,
        game.state.entities.screen,
        components.screen.Screen,
    ) orelse unreachable;
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
            const keyframes: ?[]game_state.ElementsRendererConfig.AnimationKeyFrame = er.keyframes;
            defer game.state.allocator.free(vertexShader);
            defer game.state.allocator.free(fragmentShader);
            defer game.state.allocator.free(positions);
            defer game.state.allocator.free(indices);
            defer if (texcoords) |t| game.state.allocator.free(t);
            defer if (normals) |n| game.state.allocator.free(n);
            defer if (keyframes) |kf| game.state.allocator.free(kf);
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

            var builder: *gfx.buffer_data.AttributeBuilder = game.state.allocator.create(gfx.buffer_data.AttributeBuilder) catch unreachable;
            defer game.state.allocator.destroy(builder);
            builder.* = gfx.buffer_data.AttributeBuilder.init(@intCast(positions.len), vbo, gl.STATIC_DRAW);
            defer builder.deinit();
            var pos_loc: gl.Uint = 0;
            var tc_loc: gl.Uint = 0;
            var nor_loc: gl.Uint = 0;
            // same order as defined in shader gen
            pos_loc = builder.definFloatAttributeValue(3); // positions
            if (texcoords) |_| {
                tc_loc = builder.definFloatAttributeValue(2); // texture coords
            }
            if (normals) |_| {
                nor_loc = builder.definFloatAttributeValue(3); // normals
            }
            builder.initBuffer();
            for (0..positions.len) |ii| {
                var p = positions[ii];
                builder.addFloatAtLocation(pos_loc, &p, ii);
                if (texcoords) |tcs| {
                    var t = tcs[ii];
                    builder.addFloatAtLocation(tc_loc, &t, ii);
                }
                if (normals) |ns| {
                    var n = ns[ii];
                    builder.addFloatAtLocation(nor_loc, &n, ii);
                }
                builder.nextVertex();
            }
            builder.write();

            if (er.transform) |t| {
                gfx.Gfx.setUniformMat(shadergen.constants.TransformMatName, program, t);
            }

            if (er.ubo_binding_point) |ubo_binding_point| {
                var ubo: gl.Uint = 0;
                ubo = game.state.gfx.ubos.get(ubo_binding_point) orelse blk: {
                    const m = zm.identity();
                    const new_ubo = gfx.Gfx.initUniformBufferObject(m);
                    game.state.gfx.ubos.put(ubo_binding_point, new_ubo) catch unreachable;
                    break :blk new_ubo;
                };
                gfx.Gfx.setUniformBufferObject(shadergen.constants.UBOName, program, ubo, ubo_binding_point);

                var camera: ecs.entity_t = 0;

                const parent = ecs.get_parent(world, entity);
                if (parent == screen.gameDataEntity) {
                    camera = game.state.entities.game_camera;
                }
                if (parent == screen.settingDataEntity) {
                    camera = game.state.entities.settings_camera;
                }

                ecs.add(
                    game.state.world,
                    camera,
                    components.screen.Updated,
                );
            }

            if (er.animation_binding_point) |animation_binding_point| {
                if (er.keyframes) |k| {
                    var ssbo: gl.Uint = 0;
                    ssbo = game.state.gfx.ssbos.get(animation_binding_point) orelse blk: {
                        const new_ssbo = gfx.Gfx.initAnimationShaderStorageBufferObject(animation_binding_point, k);
                        game.state.gfx.ssbos.put(animation_binding_point, new_ssbo) catch unreachable;
                        break :blk new_ssbo;
                    };
                }
            }

            var texture: gl.Uint = 0;
            if (er.demo_cube_texture) |dct| {
                if (game.state.ui.data.texture_rgba_data) |d| {
                    texture = gfx.Gfx.initTextureFromColors(d[dct[0]..dct[1]]);
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
            if (er.is_instanced) {
                // Just immediately delete instances for now.
                _ = ecs.add(world, entity, components.gfx.NeedsDeletion);
                return;
            }
            _ = ecs.add(world, entity, components.gfx.CanDraw);
        }
    }
}
