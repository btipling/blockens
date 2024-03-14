const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const tags = @import("../../tags.zig");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const game_state = @import("../../../state.zig");
const gfx = @import("../../../gfx/gfx.zig");

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
            var deinit_mesh = true;
            if (ecs.get(world, entity, components.shape.Shape)) |s| {
                const sh: *const components.shape.Shape = s;
                switch (sh.shape_type) {
                    .meshed_voxel => {
                        deinit_mesh = false;
                    },
                    else => {},
                }
            }
            const parent = ecs.get_parent(world, entity);
            const vertexShader: [:0]const u8 = er.vertexShader;
            const fragmentShader: [:0]const u8 = er.fragmentShader;
            const positions: [][3]f32 = er.positions;
            const indices: []u32 = er.indices;
            const texcoords: ?[][2]f32 = er.texcoords;
            const normals: ?[][3]f32 = er.normals;
            const keyframes: ?[]game_state.ElementsRendererConfig.AnimationKeyFrame = er.keyframes;
            defer game.state.allocator.free(vertexShader);
            defer game.state.allocator.free(fragmentShader);
            defer if (keyframes) |kf| game.state.allocator.free(kf);
            defer _ = game.state.gfx.renderConfigs.remove(erc.id);
            defer game.state.allocator.destroy(er);
            defer ecs.delete(world, erc.id);

            const vao = gfx.Gfx.initVAO() catch unreachable;
            const vbo = gfx.Gfx.initVBO() catch unreachable;
            const ebo = gfx.Gfx.initEBO(indices) catch unreachable;
            const vs = gfx.Gfx.initVertexShader(vertexShader) catch unreachable;
            const fs = gfx.Gfx.initFragmentShader(fragmentShader) catch unreachable;
            const program = gfx.Gfx.initProgram(&[_]u32{ vs, fs }) catch unreachable;
            gl.useProgram(program);

            var builder: *gfx.buffer_data.AttributeBuilder = game.state.allocator.create(gfx.buffer_data.AttributeBuilder) catch unreachable;
            defer game.state.allocator.destroy(builder);
            builder.* = gfx.buffer_data.AttributeBuilder.init(@intCast(positions.len), vbo, gl.STATIC_DRAW);
            defer builder.deinit();
            var pos_loc: u32 = 0;
            var tc_loc: u32 = 0;
            var nor_loc: u32 = 0;
            var block_data_loc: u32 = 0;
            // same order as defined in shader gen
            pos_loc = builder.defineFloatAttributeValue(3);
            if (texcoords) |_| {
                tc_loc = builder.defineFloatAttributeValue(2);
            }
            if (normals) |_| {
                nor_loc = builder.defineFloatAttributeValue(3);
            }
            if (er.has_block_texture_atlas) {
                block_data_loc = builder.defineFloatAttributeValue(2);
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
                if (er.has_block_texture_atlas) {
                    var block_index: f32 = 0;
                    var num_blocks: f32 = 0;
                    if (er.block_id) |bi| {
                        block_index = @floatFromInt(game.state.ui.data.texture_atlas_block_index[@intCast(bi)]);
                        num_blocks = @floatFromInt(game.state.ui.data.texture_atlas_num_blocks);
                    }
                    var bd: [2]f32 = [_]f32{ block_index, num_blocks };
                    builder.addFloatAtLocation(block_data_loc, &bd, ii);
                }
                builder.nextVertex();
            }
            builder.write();
            if (er.is_instanced and er.block_id != null) {
                var block_instance: ?*game_state.BlockInstance = null;
                if (parent == screen.gameDataEntity) {
                    if (game.state.gfx.game_blocks.get(er.block_id.?)) |b| {
                        if (b.vbo == 0) block_instance = b;
                    }
                }
                if (parent == screen.settingDataEntity) {
                    if (game.state.gfx.settings_blocks.get(er.block_id.?)) |b| {
                        if (b.vbo == 0) block_instance = b;
                    }
                }
                if (block_instance != null) {
                    const instance_vbo = gfx.Gfx.initVBO() catch unreachable;
                    var instance_builder: *gfx.buffer_data.AttributeBuilder = game.state.allocator.create(gfx.buffer_data.AttributeBuilder) catch unreachable;
                    defer game.state.allocator.destroy(instance_builder);
                    instance_builder.* = gfx.buffer_data.AttributeBuilder.initWithLoc(
                        @intCast(positions.len),
                        instance_vbo,
                        gl.STATIC_DRAW,
                        builder.get_location(),
                    );
                    defer instance_builder.deinit();
                    const col1_loc = instance_builder.defineFloatAttributeValueWithDivisor(4, true);
                    const col2_loc = instance_builder.defineFloatAttributeValueWithDivisor(4, true);
                    const col3_loc = instance_builder.defineFloatAttributeValueWithDivisor(4, true);
                    const col4_loc = instance_builder.defineFloatAttributeValueWithDivisor(4, true);
                    const r = zm.matToArr(zm.identity());
                    instance_builder.initBuffer();
                    instance_builder.addFloatAtLocation(col1_loc, @ptrCast(r[0..4]), 0);
                    instance_builder.addFloatAtLocation(col2_loc, @ptrCast(r[4..8]), 0);
                    instance_builder.addFloatAtLocation(col3_loc, @ptrCast(r[8..12]), 0);
                    instance_builder.addFloatAtLocation(col4_loc, @ptrCast(r[12..16]), 0);
                    instance_builder.nextVertex();
                    instance_builder.write();
                    block_instance.?.vbo = instance_vbo;
                    ecs.add(world, entity, components.gfx.NeedsInstanceDataUpdate);
                }
            }

            if (er.transform) |t| {
                gfx.Gfx.setUniformMat(gfx.constants.TransformMatName, program, t);
            }

            if (er.ubo_binding_point) |ubo_binding_point| {
                var ubo: u32 = 0;
                ubo = game.state.gfx.ubos.get(ubo_binding_point) orelse blk: {
                    const m = zm.identity();
                    const new_ubo = gfx.Gfx.initUniformBufferObject(m);
                    game.state.gfx.ubos.put(ubo_binding_point, new_ubo) catch unreachable;
                    break :blk new_ubo;
                };
                gfx.Gfx.setUniformBufferObject(gfx.constants.UBOName, program, ubo, ubo_binding_point);

                var camera: ecs.entity_t = 0;
                if (parent == screen.gameDataEntity) {
                    camera = game.state.entities.sky_camera;
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
                    var ssbo: u32 = 0;
                    ssbo = game.state.gfx.ssbos.get(animation_binding_point) orelse blk: {
                        const new_ssbo = gfx.Gfx.initAnimationShaderStorageBufferObject(animation_binding_point, k);
                        game.state.gfx.ssbos.put(animation_binding_point, new_ssbo) catch unreachable;
                        break :blk new_ssbo;
                    };
                }
            }

            var texture: u32 = 0;
            if (er.demo_cube_texture) |dct| {
                if (game.state.ui.data.texture_rgba_data) |d| {
                    texture = gfx.Gfx.initTextureFromColors(d[dct[0]..dct[1]]);
                }
            }
            if (er.has_block_texture_atlas) {
                if (game.state.ui.data.texture_atlas_rgba_data) |d| {
                    texture = gfx.Gfx.initTextureAtlasFromColors(d);
                }
            } else if (er.block_id != null and game.state.gfx.blocks.contains(er.block_id.?)) {
                const block = game.state.gfx.blocks.get(er.block_id.?).?;
                texture = gfx.Gfx.initTextureFromColors(block.data.texture);
            }
            if (er.has_mob_texture) {
                const mesh_c: *const components.mob.Mesh = ecs.get(world, entity, components.mob.Mesh).?;
                const mob_c: *const components.mob.Mob = ecs.get(world, mesh_c.mob_entity, components.mob.Mob).?;
                const mob_data: *game_state.Mob = game.state.gfx.mob_data.get(mob_c.mob_id).?;
                const mesh: *game_state.MobMesh = mob_data.meshes.items[mesh_c.mesh_id];
                texture = gfx.Gfx.initTextureFromImage(mesh.texture.?) catch unreachable;
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
            ecs.add(world, entity, components.gfx.CanDraw);
            if (deinit_mesh) {
                defer game.state.allocator.free(positions);
                defer game.state.allocator.free(indices);
                defer if (texcoords) |t| game.state.allocator.free(t);
                defer if (normals) |n| game.state.allocator.free(n);
            }
        }
    }
}
