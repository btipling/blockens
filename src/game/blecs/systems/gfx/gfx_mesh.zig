const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const ztracy = @import("ztracy");
const config = @import("config");
const tags = @import("../../tags.zig");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const game_state = @import("../../../state.zig");
const mob = @import("../../../mob.zig");
const chunk = @import("../../../chunk.zig");
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
            if (config.use_tracy) {
                const tracy_zone = ztracy.ZoneNC(@src(), "GfxMeshSystem", 0x00_ff_f3_f0);
                defer tracy_zone.End();
                meshSystem(world, entity, screen, erc);
            } else {
                meshSystem(world, entity, screen, erc);
            }
        }
    }
}

fn meshSystem(world: *ecs.world_t, entity: ecs.entity_t, screen: *const components.screen.Screen, erc: components.gfx.ElementsRendererConfig) void {
    const er: *game_state.ElementsRendererConfig = game.state.gfx.renderConfigs.get(erc.id) orelse {
        std.debug.print("couldn't find render config for {d}\n", .{erc.id});
        return;
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
    const keyframes: ?[]game_state.ElementsRendererConfig.AnimationKeyFrame = er.keyframes;
    defer game.state.allocator.free(vertexShader);
    defer game.state.allocator.free(fragmentShader);
    defer if (keyframes) |kf| game.state.allocator.free(kf);
    defer _ = game.state.gfx.renderConfigs.remove(erc.id);
    defer game.state.allocator.destroy(er);
    defer ecs.delete(world, erc.id);

    const vao = gfx.Gfx.initVAO() catch unreachable;
    const vbo = gfx.Gfx.initVBO() catch unreachable;
    var ebo: u32 = 0;
    var c: ?*chunk.Chunk = null;
    if (er.is_multi_draw) {
        const chunk_c: *const components.block.Chunk = ecs.get(world, entity, components.block.Chunk).?;
        if (parent == screen.gameDataEntity) {
            c = game.state.gfx.game_chunks.get(chunk_c.wp);
        }
        if (parent == screen.settingDataEntity) {
            c = game.state.gfx.settings_chunks.get(chunk_c.wp);
        }
    }
    if (er.is_multi_draw) {
        if (c) |_c| {
            var ial = std.ArrayList(u32).init(game.state.allocator);
            defer ial.deinit();
            for (_c.elements.items) |e| {
                ial.appendSlice(e.mesh_data.indices) catch unreachable;
            }
            ebo = gfx.Gfx.initEBO(ial.items) catch unreachable;
        }
    } else {
        ebo = gfx.Gfx.initEBO(er.mesh_data.indices) catch unreachable;
    }
    const vs = gfx.Gfx.initVertexShader(vertexShader) catch unreachable;
    const fs = gfx.Gfx.initFragmentShader(fragmentShader) catch unreachable;
    const program = gfx.Gfx.initProgram(&[_]u32{ vs, fs }) catch unreachable;
    gl.useProgram(program);

    var builder: *gfx.buffer_data.AttributeBuilder = game.state.allocator.create(gfx.buffer_data.AttributeBuilder) catch unreachable;
    defer game.state.allocator.destroy(builder);
    var num_elements: usize = 1;
    if (er.is_multi_draw) {
        num_elements = c.?.elements.items.len;
    }
    builder.* = gfx.buffer_data.AttributeBuilder.init(
        @intCast(er.mesh_data.positions.len * num_elements),
        vbo,
        gl.STATIC_DRAW,
    );
    defer builder.deinit();
    // if (er.edges != null) builder.debug = true;
    var pos_loc: u32 = 0;
    var tc_loc: u32 = 0;
    var nor_loc: u32 = 0;
    var edge_loc: u32 = 0;
    var baryc_loc: u32 = 0;
    var block_data_loc: u32 = 0;
    var attr_trans_loc: u32 = 0;
    // same order as defined in shader gen
    pos_loc = builder.defineFloatAttributeValue(3);
    if (er.mesh_data.texcoords) |_| {
        tc_loc = builder.defineFloatAttributeValue(2);
    }
    if (er.mesh_data.normals) |_| {
        nor_loc = builder.defineFloatAttributeValue(3);
    }
    if (er.mesh_data.edges) |_| {
        edge_loc = builder.defineFloatAttributeValue(2);
    }
    if (er.mesh_data.barycentric) |_| {
        baryc_loc = builder.defineFloatAttributeValue(3);
    }
    if (er.has_block_texture_atlas) {
        block_data_loc = builder.defineFloatAttributeValue(2);
    }
    if (er.is_multi_draw and er.has_attr_translation) {
        attr_trans_loc = builder.defineFloatAttributeValue(4);
    }
    builder.initBuffer();
    if (er.is_multi_draw) {
        if (c) |_c| {
            for (_c.elements.items, 0..) |e, ei| {
                // if (ei != 0) break;
                const vertex_offset = er.mesh_data.positions.len * ei;
                const md = e.mesh_data;
                for (0..md.positions.len) |ii| {
                    var p = md.positions[ii];
                    const vertex_index: usize = ii + vertex_offset;
                    builder.addFloatAtLocation(pos_loc, &p, vertex_index);
                    if (md.texcoords) |tcs| {
                        var t = tcs[ii];
                        builder.addFloatAtLocation(tc_loc, &t, vertex_index);
                    }
                    if (md.normals) |ns| {
                        var n = ns[ii];
                        builder.addFloatAtLocation(nor_loc, &n, vertex_index);
                    }
                    if (md.edges) |es| {
                        var ec = es[ii];
                        builder.addFloatAtLocation(edge_loc, &ec, vertex_index);
                    }
                    if (md.barycentric) |bs| {
                        var bc = bs[@mod(ii, 3)]; // barycentric coordinates: there are only 3 values, only work for cuboids
                        builder.addFloatAtLocation(baryc_loc, &bc, vertex_index);
                    }
                    if (er.has_block_texture_atlas) {
                        const bi = e.block_id;
                        const block_index: f32 = @floatFromInt(game.state.ui.data.texture_atlas_block_index[@intCast(bi)]);
                        const num_blocks: f32 = @floatFromInt(game.state.ui.data.texture_atlas_num_blocks);
                        var bd: [2]f32 = [_]f32{ block_index, num_blocks };
                        builder.addFloatAtLocation(block_data_loc, &bd, vertex_index);
                    }
                    if (er.has_attr_translation) {
                        var atr_data: [4]f32 = e.translation;
                        builder.addFloatAtLocation(attr_trans_loc, &atr_data, vertex_index);
                    }
                    builder.nextVertex();
                }
            }
        }
    } else {
        for (0..er.mesh_data.positions.len) |ii| {
            var p = er.mesh_data.positions[ii];
            builder.addFloatAtLocation(pos_loc, &p, ii);
            if (er.mesh_data.texcoords) |tcs| {
                var t = tcs[ii];
                builder.addFloatAtLocation(tc_loc, &t, ii);
            }
            if (er.mesh_data.normals) |ns| {
                var n = ns[ii];
                builder.addFloatAtLocation(nor_loc, &n, ii);
            }
            if (er.mesh_data.edges) |es| {
                var ec = es[ii];
                builder.addFloatAtLocation(edge_loc, &ec, ii);
            }
            if (er.mesh_data.barycentric) |bs| {
                var bc = bs[@mod(ii, 3)]; // See "barycentric coordinates" above
                builder.addFloatAtLocation(baryc_loc, &bc, ii);
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
            block_instance.?.vbo = gfx.Gfx.initTransformsUBO(
                er.mesh_data.positions.len,
                builder.get_location(),
            ) catch unreachable;
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
        const mob_data: *mob.Mob = game.state.gfx.mob_data.get(mob_c.mob_id).?;
        const mesh: *mob.MobMesh = mob_data.meshes.items[mesh_c.mesh_id];
        texture = gfx.Gfx.initTextureFromImage(mesh.texture.?) catch unreachable;
    }

    ecs.remove(world, entity, components.gfx.ElementsRendererConfig);
    _ = ecs.set(world, entity, components.gfx.ElementsRenderer, .{
        .program = program,
        .vao = vao,
        .vbo = vbo,
        .ebo = ebo,
        .texture = texture,
        .numIndices = @intCast(er.mesh_data.indices.len),
    });
    ecs.add(world, entity, components.gfx.CanDraw);
    if (deinit_mesh) er.mesh_data.deinit();
}
