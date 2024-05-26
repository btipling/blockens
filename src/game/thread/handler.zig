var handler: *Handler = undefined;

const Handler = struct {};

const maxHandlersPerFrame = 1000;

pub fn init() !void {
    handler = try game.state.allocator.create(Handler);
    handler.* = .{};
}

pub fn deinit() void {
    game.state.allocator.destroy(handler);
}

pub fn handle_incoming() !void {
    var i: u32 = 0;
    while (buffer.next_message()) |msg| {
        const mt: buffer.buffer_message_type = @enumFromInt(msg.type);
        switch (mt) {
            .startup => try handle_startup(msg),
            .chunk_gen => handle_demo_chunk_gen(msg),
            .chunk_mesh => handle_chunk_mesh(msg),
            .sub_chunk_mesh => handle_sub_chunks_mesh(msg),
            .sub_chunk_build => handle_sub_chunks_build(msg),
            .lighting => handle_lighting(msg),
            .lighting_cross_chunk => handle_lighting_cross_chunk(msg),
            .load_chunk => handle_load_chunk(msg),
            .demo_descriptor_gen => handle_demo_descriptor_gen(msg),
            .demo_terrain_gen => handle_demo_terrain_gen(msg),
            .world_descriptor_gen => handle_world_descriptor_gen(msg),
            .world_terrain_gen => handle_world_terrain_gen(msg),
            .player_pos => handle_player_pos(msg),
        }
        i += 0;
        if (i >= maxHandlersPerFrame) return;
    }
}

fn handle_startup(msg: buffer.buffer_message) !void {
    if (!buffer.progress_report(msg).done) return;
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    _ = switch (bd) {
        buffer.buffer_data.startup => |d| d,
        else => return,
    };

    try game.state.populateUIOptions();
    screen_helpers.showTitleScreen();
    blecs.entities.block.init();
}

fn handle_demo_chunk_gen(msg: buffer.buffer_message) void {
    if (!buffer.progress_report(msg).done) return;
    const is_demo: bool = buffer.is_demo_chunk(msg) catch return;
    if (!is_demo) return;
    const c_data: buffer.buffer_data = buffer.get_data(msg) orelse return;
    const chunk_data: buffer.chunk_gen_data = switch (c_data) {
        buffer.buffer_data.chunk_gen => |d| d,
        else => return,
    };
    errdefer game.state.allocator.free(chunk_data.chunk_data);
    if (game.state.blocks.generated_settings_chunks.get(chunk_data.wp)) |data| {
        game.state.allocator.free(data);
    }
    game.state.blocks.generated_settings_chunks.put(chunk_data.wp, chunk_data.chunk_data) catch @panic("OOM");
    if (chunk_data.sub_chunks) {
        game.state.ui.resetDemoSorter();
        game.state.jobs.meshSubChunk(false, true);
        return;
    }
    blecs.entities.screen.initDemoChunk(true);
}

fn handle_chunk_mesh(msg: buffer.buffer_message) void {
    if (!buffer.progress_report(msg).done) return;
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    const mesh_data: buffer.chunk_mesh_data = switch (bd) {
        buffer.buffer_data.chunk_mesh => |d| d,
        else => return,
    };
    const world = mesh_data.world orelse return;
    const entity = mesh_data.entity orelse return;
    if (mesh_data.empty) {
        if (entity == 0 or !blecs.ecs.is_alive(world, entity)) return;
        if (blecs.ecs.has_id(world, entity, blecs.ecs.id(blecs.components.gfx.ElementsRenderer))) {
            blecs.ecs.add(world, entity, blecs.components.gfx.NeedsDeletion);
        }
        return;
    }
    if (entity == 0 or !blecs.ecs.is_alive(world, entity)) {
        const chunk_entity = init_chunk_entity(world, mesh_data.chunk);
        blecs.ecs.add(world, chunk_entity, blecs.components.block.NeedsMeshRendering);
        return;
    }
    blecs.ecs.add(world, entity, blecs.components.block.NeedsMeshRendering);
}

fn handle_sub_chunks_mesh(msg: buffer.buffer_message) void {
    const pr = buffer.progress_report(msg);
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    const scd: buffer.sub_chunk_mesh_data = switch (bd) {
        buffer.buffer_data.sub_chunk_mesh => |d| d,
        else => return,
    };
    var sorter: *chunk.sub_chunk.sorter = undefined;
    if (scd.is_settings) {
        sorter = game.state.ui.demo_sub_chunks_sorter;
    } else {
        sorter = game.state.ui.game_sub_chunks_sorter;
    }
    for (scd.sub_chunks) |sc| {
        if (sc.chunker.total_indices_count > 0) {
            sorter.addSubChunk(sc);
        } else {
            sc.deinit();
        }
    }
    game.state.ui.load_percentage_load_sub_chunks = pr.percent;
    if (!pr.done) return;
    std.debug.print("initing sub chunks\n", .{});
    game.state.jobs.buildSubChunks(scd.is_terrain, scd.is_settings);
}

fn handle_sub_chunks_build(msg: buffer.buffer_message) void {
    const pr = buffer.progress_report(msg);
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    const scd: buffer.sub_chunk_build_data = switch (bd) {
        buffer.buffer_data.sub_chunk_build => |d| d,
        else => return,
    };
    if (!pr.done) return;
    std.debug.print("initing sub chunks\n", .{});
    if (scd.is_settings) {
        blecs.entities.screen.initDemoSubChunks(true, scd.is_terrain);
        return;
    }
    blecs.entities.screen.initGameSubChunks();
    screen_helpers.showGameScreen();
    ui_helpers.loadCharacterInWorld();
}

fn handle_lighting(msg: buffer.buffer_message) void {
    const pr = buffer.progress_report(msg);
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    const ld: buffer.lightings_data = switch (bd) {
        buffer.buffer_data.lighting => |d| d,
        else => return,
    };
    game.state.ui.load_percentage_lighting_initial = pr.percent;
    if (!pr.done) return;
    _ = game.state.jobs.lighting_cross_chunk(ld.world_id);
}

fn handle_lighting_cross_chunk(msg: buffer.buffer_message) void {
    const pr = buffer.progress_report(msg);
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    const ld: buffer.lightings_data = switch (bd) {
        buffer.buffer_data.lighting => |d| d,
        else => return,
    };
    game.state.ui.load_percentage_lighting_cross_chunk = pr.percent;
    if (!pr.done) return;
    _ = game.state.jobs.loadChunks(ld.world_id, true, game.state.ui.sub_chunks);
}

fn handle_load_chunk(msg: buffer.buffer_message) void {
    const pr = buffer.progress_report(msg);
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    const lcd: buffer.load_chunk_data = switch (bd) {
        buffer.buffer_data.load_chunk => |d| d,
        else => return,
    };
    game.state.ui.load_percentage_load_chunks = pr.percent;
    if (lcd.exists) {
        game.state.ui.world_chunk_table_data.put(
            game.state.ui.allocator,
            lcd.wp_t,
            lcd.cfg_t,
        ) catch @panic("OOM");
        game.state.ui.world_chunk_table_data.put(
            game.state.ui.allocator,
            lcd.wp_b,
            lcd.cfg_b,
        ) catch @panic("OOM");
    }
    if (!pr.done) return;
    if (!lcd.start_game) return;
    if (lcd.sub_chunks) {
        game.state.ui.resetGameSorter();
        game.state.jobs.meshSubChunk(false, false);
        ui_helpers.loadChunksInWorld(false);
        return;
    }
    ui_helpers.loadChunksInWorld(true);
    screen_helpers.showGameScreen();
    ui_helpers.loadCharacterInWorld();
}

fn handle_demo_descriptor_gen(msg: buffer.buffer_message) void {
    if (!buffer.progress_report(msg).done) return;
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    const dg_d: buffer.demo_descriptor_gen_data = switch (bd) {
        buffer.buffer_data.demo_descriptor_gen => |d| d,
        else => return,
    };

    _ = game.state.jobs.generateDemoTerrain(
        dg_d.desc_root,
        dg_d.sub_chunks,
        dg_d.offset_x,
        dg_d.offset_z,
    );
}

fn handle_world_descriptor_gen(msg: buffer.buffer_message) void {
    if (!buffer.progress_report(msg).done) return;
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    const dg_d: buffer.world_descriptor_gen_data = switch (bd) {
        buffer.buffer_data.world_descriptor_gen => |d| d,
        else => return,
    };
    std.debug.print("generated world descriptors for world: {d}\n", .{dg_d.world_id});
    screen_helpers.showLoadingScreen();
    _ = game.state.jobs.generateWorldTerrain(dg_d.world_id, dg_d.descriptors);
}

fn handle_world_terrain_gen(msg: buffer.buffer_message) void {
    const pr = buffer.progress_report(msg);
    if (!buffer.progress_report(msg).done) return;
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    const dg_d: buffer.world_terrain_gen_data = switch (bd) {
        buffer.buffer_data.world_terrain_gen => |d| d,
        else => return,
    };
    game.state.ui.load_percentage_world_gen = pr.percent;
    if (!pr.done) return;
    std.debug.print("generated world terrain for world: {d}\n", .{dg_d.world_id});
    for (dg_d.descriptors.items) |d| d.deinit();
    dg_d.descriptors.deinit();
    game.state.ui.world_loaded_id = dg_d.world_id;

    _ = game.state.jobs.findPlayerPosition(game.state.ui.world_loaded_id);
}

fn handle_player_pos(msg: buffer.buffer_message) void {
    if (!buffer.progress_report(msg).done) return;
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    _ = switch (bd) {
        buffer.buffer_data.player_pos => |d| d,
        else => return,
    };

    _ = game.state.jobs.lighting(game.state.ui.world_loaded_id);
}

fn handle_demo_terrain_gen(msg: buffer.buffer_message) void {
    const pr = buffer.progress_report(msg);
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    const tg_d: buffer.demo_terrain_gen_data = switch (bd) {
        buffer.buffer_data.demo_terrain_gen => |d| d,
        else => return,
    };
    const wp = chunk.worldPosition.initFromPositionV(tg_d.position);
    if (!tg_d.succeeded) return;
    game.state.blocks.generated_settings_chunks.put(wp, tg_d.data.?) catch @panic("OOM");
    if (!pr.done) return;
    defer tg_d.desc_root.deinit();
    std.debug.print("terrain generated {d}.\n", .{
        game.state.blocks.generated_settings_chunks.count(),
    });
    if (tg_d.sub_chunks) {
        blecs.entities.screen.clearDemoObjects();
        game.state.ui.resetDemoSorter();
        game.state.jobs.meshSubChunk(true, true);
        return;
    }
    blecs.entities.screen.initDemoTerrainGen(true);
}

fn init_chunk_entity(world: *blecs.ecs.world_t, c: *chunk.Chunk) blecs.ecs.entity_t {
    const wp = c.wp;
    var chunk_entity: blecs.ecs.entity_t = 0;
    if (c.is_settings) {
        chunk_entity = helpers.new_child(world, blecs.entities.screen.settings_data);
    } else {
        chunk_entity = helpers.new_child(world, blecs.entities.screen.game_data);
    }

    blecs.ecs.add_pair(
        world,
        c.entity,
        blecs.entities.block.HasChunkRenderer,
        chunk_entity,
    );
    _ = blecs.ecs.set(world, chunk_entity, blecs.components.block.Chunk, .{
        .wp = wp,
    });
    blecs.ecs.add(world, chunk_entity, blecs.components.block.UseMultiDraw);
    return chunk_entity;
}

const std = @import("std");
const game = @import("../game.zig");
const blecs = @import("../blecs/blecs.zig");
const block = @import("../block/block.zig");
const chunk = block.chunk;
const buffer = @import("./buffer.zig");
const helpers = @import("../blecs/helpers.zig");
const ui_helpers = @import("../blecs/systems/ui/ui_helpers.zig");
const screen_helpers = @import("../blecs/systems/screen_helpers.zig");
