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
    ecs.SYSTEM(game.state.world, "GfxMeshSystem", ecs.PreStore, @constCast(&s));
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
    if (config.use_tracy) ztracy.Message("starting mesh system");
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
    const vertexShader: ?[:0]const u8 = er.vertexShader;
    const fragmentShader: ?[:0]const u8 = er.fragmentShader;
    const keyframes: ?[]game_state.ElementsRendererConfig.AnimationKeyFrame = er.keyframes;

    if (config.use_tracy) ztracy.Message("initing gfx");
    const vao = gfx.Gfx.initVAO() catch @panic("nope");
    const vbo = gfx.Gfx.initVBO() catch @panic("nope");
    var ebo: u32 = 0;

    if (config.use_tracy) ztracy.Message("setting up chunk");
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

    if (config.use_tracy) ztracy.Message("setting up shaders");
    var vs: u32 = 0;
    var fs: u32 = 0;
    if (er.is_multi_draw) {
        vs = gfx.Gfx.initMultiDrawVertexShader(vertexShader) catch @panic("nope");
        fs = gfx.Gfx.initMultiDrawFragmentShader(fragmentShader) catch @panic("nope");
    } else {
        vs = gfx.Gfx.initVertexShader(vertexShader) catch @panic("nope");
        fs = gfx.Gfx.initFragmentShader(fragmentShader) catch @panic("nope");
    }
    const program = gfx.Gfx.initProgram(&[_]u32{ vs, fs }) catch @panic("nope");
    gl.useProgram(program);

    var builder: *gfx.buffer_data.AttributeBuilder = undefined;
    if (er.is_multi_draw) {
        if (c) |_c| {
            // The only time we need to read from chunk data is in this block.
            _c.mutex.lock();
            defer _c.mutex.unlock();

            if (config.use_tracy) ztracy.Message("adding indexes to EBO");
            const indices = _c.indices orelse std.debug.panic("expected indices from chunk\n", .{});
            ebo = gfx.Gfx.initEBO(indices) catch @panic("nope");
            game.state.allocator.free(indices);
            _c.indices = null;

            if (config.use_tracy) ztracy.Message("building multidraw shader attribute variables");
            builder = _c.attr_builder orelse std.debug.panic("expected attribuilder from chunk\n", .{});
            builder.vbo = vbo;
            builder.usage = gl.STATIC_DRAW;
            _c.attr_builder = null;
        }
    } else {
        ebo = gfx.Gfx.initEBO(er.mesh_data.indices[0..]) catch @panic("nope");
    }

    if (!er.is_multi_draw) {
        if (config.use_tracy) ztracy.Message("building non-multidraw shader attribute variables");
        builder = game.state.allocator.create(
            gfx.buffer_data.AttributeBuilder,
        ) catch @panic("OOM");
        const num_elements: usize = 1;
        builder.* = gfx.buffer_data.AttributeBuilder.init(
            @intCast(er.mesh_data.positions.len * num_elements),
            vbo,
            gl.STATIC_DRAW,
        );

        if (config.use_tracy) ztracy.Message("defining shader attribute variables");
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
        if (er.has_attr_translation) {
            attr_trans_loc = builder.defineFloatAttributeValue(4);
        }

        if (config.use_tracy) ztracy.Message("initializing vbo buffer builder");
        builder.initBuffer();
        for (0..er.mesh_data.positions.len) |ii| {
            if (config.use_tracy) ztracy.Message("adding element vertex to vbo buffer builder");
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

    if (config.use_tracy) ztracy.Message("writing vbo buffer to gpu");
    builder.write();

    if (config.use_tracy) ztracy.Message("writing uniforms to gpu");
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
            block_instance.?.vbo = gfx.Gfx.initTransformsVBO(
                er.mesh_data.positions.len,
                builder.get_location(),
            ) catch @panic("nope");
            ecs.add(world, entity, components.gfx.NeedsInstanceDataUpdate);
        }
    }

    if (er.transform) |t| {
        gfx.Gfx.setUniformMat(gfx.constants.TransformMatName, program, t);
    }

    if (config.use_tracy) ztracy.Message("writing uniform buffer objects to gpu");
    if (er.ubo_binding_point) |ubo_binding_point| {
        var ubo: u32 = 0;
        ubo = game.state.gfx.ubos.get(ubo_binding_point) orelse blk: {
            const m = zm.identity();
            const new_ubo = gfx.Gfx.initUniformBufferObject(m);
            game.state.gfx.ubos.put(ubo_binding_point, new_ubo) catch @panic("OOM");
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

    if (config.use_tracy) ztracy.Message("writing ssbos to gpu");
    if (er.animation_binding_point) |animation_binding_point| {
        if (er.keyframes) |k| {
            var ssbo: u32 = 0;
            ssbo = game.state.gfx.ssbos.get(animation_binding_point) orelse blk: {
                const new_ssbo = gfx.Gfx.initAnimationShaderStorageBufferObject(animation_binding_point, k);
                game.state.gfx.ssbos.put(animation_binding_point, new_ssbo) catch @panic("nope");
                break :blk new_ssbo;
            };
        }
    }

    if (config.use_tracy) ztracy.Message("writing textures to gpu");
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
        texture = gfx.Gfx.initTextureFromImage(mesh.texture.?) catch @panic("nope");
    }

    if (config.use_tracy) ztracy.Message("ready to draw");
    ecs.add(world, entity, components.gfx.CanDraw);
    gl.finish();

    if (config.use_tracy) ztracy.Message("cleaning up memory");
    ecs.remove(world, entity, components.gfx.ElementsRendererConfig);
    _ = ecs.set(world, entity, components.gfx.ElementsRenderer, .{
        .program = program,
        .vao = vao,
        .vbo = vbo,
        .ebo = ebo,
        .texture = texture,
        .numIndices = @intCast(er.mesh_data.indices.len),
    });
    if (vertexShader) |v| game.state.allocator.free(v);
    if (fragmentShader) |f| game.state.allocator.free(f);
    if (keyframes) |kf| game.state.allocator.free(kf);
    _ = game.state.gfx.renderConfigs.remove(erc.id);
    ecs.delete(world, erc.id);
    if (deinit_mesh) er.mesh_data.deinit();
    game.state.allocator.destroy(er);
    builder.deinit();
    game.state.allocator.destroy(builder);
    if (config.use_tracy) ztracy.Message("gfx mesh system is done");
}
