const system_name = "GfxMeshSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.PreStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.gfx.ElementsRendererConfig) };
    desc.run = if (config.use_tracy) runWithTrace else run;
    return desc;
}

fn runWithTrace(it: *ecs.iter_t) callconv(.C) void {
    ztracy.Message(system_name);
    const tracy_zone = ztracy.ZoneNC(@src(), system_name, 0x00_ff_f3_f0);
    defer tracy_zone.End();
    return run(it);
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const screen: *const components.screen.Screen = ecs.get(
        game.state.world,
        game.state.entities.screen,
        components.screen.Screen,
    ) orelse return;
    while (ecs.iter_next(it)) {
        const world = it.world;
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            const ers: []components.gfx.ElementsRendererConfig = ecs.field(it, components.gfx.ElementsRendererConfig, 1) orelse return;
            const erc = ers[i];
            meshSystem(world, entity, screen, erc);
        }
    }
}

fn meshSystem(world: *ecs.world_t, entity: ecs.entity_t, screen: *const components.screen.Screen, erc: components.gfx.ElementsRendererConfig) void {
    if (config.use_tracy) ztracy.Message("starting mesh system");
    const er: *gfx.ElementsRendererConfig = game.state.gfx.renderConfigs.get(erc.id) orelse {
        std.debug.print("couldn't find render config for {d}\n", .{erc.id});
        return;
    };

    const parent = ecs.get_parent(world, entity);
    const vertexShader: ?[:0]const u8 = er.vertexShader;
    const fragmentShader: ?[:0]const u8 = er.fragmentShader;

    if (config.use_tracy) ztracy.Message("initing gfx");
    const vao = gfx.gl.Gl.initVAO() catch @panic("nope");
    const vbo = gfx.gl.Gl.initVBO() catch @panic("nope");
    var ebo: u32 = 0;

    if (config.use_tracy) ztracy.Message("setting up chunk");
    var c: ?*chunk.Chunk = null;
    if (er.is_multi_draw) {
        const chunk_c: *const components.block.Chunk = ecs.get(world, entity, components.block.Chunk).?;
        if (parent == screen.gameDataEntity) {
            c = game.state.blocks.game_chunks.get(chunk_c.wp);
        }
        if (parent == screen.settingDataEntity) {
            c = game.state.blocks.settings_chunks.get(chunk_c.wp);
        }
    }
    if (c) |_c| {
        if (_c.indices == null) {
            ecs.delete(world, entity);
            if (vertexShader) |v| game.state.allocator.free(v);
            if (fragmentShader) |f| game.state.allocator.free(f);
            _ = game.state.gfx.renderConfigs.remove(erc.id);
            ecs.delete(world, erc.id);
            er.mesh_data.deinit();
            game.state.allocator.destroy(er);
            return;
        }
    }

    if (config.use_tracy) ztracy.Message("setting up shaders");
    var vs: u32 = 0;
    var fs: u32 = 0;
    if (er.is_multi_draw) {
        vs = gfx.gl.Gl.initMultiDrawVertexShader(vertexShader) catch @panic("nope");
        fs = gfx.gl.Gl.initMultiDrawFragmentShader(fragmentShader) catch @panic("nope");
    } else {
        vs = gfx.gl.Gl.initVertexShader(vertexShader) catch @panic("nope");
        fs = gfx.gl.Gl.initFragmentShader(fragmentShader) catch @panic("nope");
    }
    const program = gfx.gl.Gl.initProgram(&[_]u32{ vs, fs }, !er.is_multi_draw) catch @panic("nope");
    gl.useProgram(program);

    var builder: *gfx.buffer_data.AttributeBuilder = undefined;
    if (er.is_multi_draw) {
        if (c) |_c| {
            // The only time we need to read from chunk data is in this block.
            _c.mutex.lock();
            defer _c.mutex.unlock();

            if (config.use_tracy) ztracy.Message("adding indexes to EBO");
            const indices = _c.indices orelse std.debug.panic("expected indices from chunk\n", .{});
            game.state.ui.gfx_triangle_count += @divFloor(indices.len, 3);
            ebo = gfx.gl.Gl.initEBO(indices) catch @panic("nope");
            game.state.allocator.free(indices);
            _c.indices = null;

            if (config.use_tracy) ztracy.Message("building multidraw shader attribute variables");
            builder = _c.attr_builder orelse std.debug.panic("expected attribuilder from chunk\n", .{});
            builder.vbo = vbo;
            builder.usage = gl.STATIC_DRAW;
            _c.attr_builder = null;
        }
    } else if (er.is_sub_chunks) {
        var sorter: *chunk.sub_chunk.sorter = undefined;
        if (parent == screen.gameDataEntity) {
            sorter = game.state.gfx.game_sub_chunks_sorter;
        }
        if (parent == screen.settingDataEntity) {
            sorter = game.state.gfx.demo_sub_chunks_sorter;
        }
        game.state.ui.gfx_triangle_count = @divFloor(sorter.num_indices, 3);
        game.state.ui.gfx_meshes_drawn = sorter.all_sub_chunks.items.len;
    } else {
        ebo = gfx.gl.Gl.initEBO(er.mesh_data.indices[0..]) catch @panic("nope");
    }

    if (!er.is_multi_draw and !er.is_sub_chunks) {
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
        if (!er.is_sub_chunks) builder.initBuffer();
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
                    block_index = @floatFromInt(game.state.ui.texture_atlas_block_index[@intCast(bi)]);
                    num_blocks = @floatFromInt(game.state.ui.texture_atlas_num_blocks);
                }
                var bd: [2]f32 = [_]f32{ block_index, num_blocks };
                builder.addFloatAtLocation(block_data_loc, &bd, ii);
            }
            builder.nextVertex();
        }
    }

    if (config.use_tracy) ztracy.Message("writing vbo buffer to gpu");
    if (!er.is_sub_chunks) builder.write();

    if (config.use_tracy) ztracy.Message("writing uniforms to gpu");
    if (er.transform) |t| {
        gfx.gl.Gl.setUniformMat(gfx.constants.TransformMatName, program, t);
    }

    if (config.use_tracy) ztracy.Message("writing uniform buffer objects to gpu");
    if (er.ubo_binding_point) |ubo_binding_point| {
        var ubo: u32 = 0;
        ubo = game.state.gfx.ubos.get(ubo_binding_point) orelse blk: {
            const m = zm.identity();
            const new_ubo = gfx.gl.Gl.initUniformBufferObject(m);
            game.state.gfx.ubos.put(ubo_binding_point, new_ubo) catch @panic("OOM");
            break :blk new_ubo;
        };
        gfx.gl.Gl.setUniformBufferObject(gfx.constants.UBOName, program, ubo, ubo_binding_point);

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

    if (config.use_tracy) ztracy.Message("writing textures to gpu");
    var texture: u32 = 0;
    if (er.demo_cube_texture) |dct| {
        if (game.state.ui.texture_rgba_data) |d| {
            texture = gfx.gl.Gl.initTextureFromColors(d[dct[0]..dct[1]]);
        }
    }
    if (er.has_block_texture_atlas) {
        if (game.state.ui.texture_atlas_rgba_data) |d| {
            texture = gfx.gl.Gl.initTextureAtlasFromColors(d);
        }
    } else if (er.block_id != null and game.state.blocks.blocks.contains(er.block_id.?)) {
        const b = game.state.blocks.blocks.get(er.block_id.?).?;
        texture = gfx.gl.Gl.initTextureFromColors(b.data.texture);
    }
    if (er.has_mob_texture) {
        const mesh_c: *const components.mob.Mesh = ecs.get(world, entity, components.mob.Mesh).?;
        const mob_c: *const components.mob.Mob = ecs.get(world, mesh_c.mob_entity, components.mob.Mob).?;
        const mob_data: *mob.Mob = game.state.gfx.mob_data.get(mob_c.mob_id).?;
        const mesh: *mob.MobMesh = mob_data.meshes.items[mesh_c.mesh_id];
        texture = gfx.gl.Gl.initTextureFromImage(mesh.texture.?) catch @panic("nope");
    }

    if (config.use_tracy) ztracy.Message("ready to draw");
    if (er.is_sub_chunks) std.debug.print("can draw sub chunks\n", .{});
    ecs.add(world, entity, components.gfx.CanDraw);
    gl.finish();

    if (config.use_tracy) ztracy.Message("cleaning up memory");
    ecs.remove(world, entity, components.gfx.ElementsRendererConfig);
    const num_indices: usize = if (er.is_sub_chunks) gfx.mesh.cube_indices.len else er.mesh_data.indices.len;
    _ = ecs.set(world, entity, components.gfx.ElementsRenderer, .{
        .program = program,
        .vao = vao,
        .vbo = vbo,
        .ebo = ebo,
        .texture = texture,
        .num_indices = @intCast(num_indices),
    });
    if (vertexShader) |v| game.state.allocator.free(v);
    if (fragmentShader) |f| game.state.allocator.free(f);
    _ = game.state.gfx.renderConfigs.remove(erc.id);
    ecs.delete(world, erc.id);
    er.mesh_data.deinit();
    if (!er.is_sub_chunks) builder.deinit();
    game.state.allocator.destroy(er);
    if (config.use_tracy) ztracy.Message("gfx mesh system is done");
}

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
const mob = @import("../../../mob.zig");
const gfx = @import("../../../gfx/gfx.zig");
const block = @import("../../../block/block.zig");
const chunk = block.chunk;
