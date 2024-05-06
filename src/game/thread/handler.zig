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
            .chunk_gen => try handle_chunk_gen(msg),
            .chunk_mesh => handle_chunk_mesh(msg),
            .lighting => handle_lighting(msg),
            .lighting_cross_chunk => handle_lighting_cross_chunk(msg),
            .load_chunk => handle_load_chunk(msg),
            .terrain_gen => handle_terrain_gen(msg),
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

fn handle_chunk_gen(msg: buffer.buffer_message) !void {
    if (!buffer.progress_report(msg).done) return;
    if (try buffer.is_demo_chunk(msg)) return handle_demo_chunk_gen(msg);
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    var cleared_data = false;
    const chunk_data: buffer.chunk_gen_data = switch (bd) {
        buffer.buffer_data.chunk_gen => |d| d,
        else => return,
    };
    errdefer if (!cleared_data) game.state.allocator.free(chunk_data.chunk_data);
    var ch_cfg = game.state.ui.world_chunk_table_data.get(chunk_data.wp) orelse {
        std.debug.panic("handled chunk gen for non existent chunk in chunk table\n", .{});
    };
    ch_cfg.chunkData = chunk_data.chunk_data;
    if (game.state.ui.world_chunk_table_data.get(chunk_data.wp)) |cd| {
        game.state.allocator.free(cd.chunkData);
        cleared_data = true;
    }
    game.state.ui.world_chunk_table_data.put(chunk_data.wp, ch_cfg) catch @panic("OOM");
}

fn handle_demo_chunk_gen(msg: buffer.buffer_message) void {
    if (!buffer.progress_report(msg).done) return;
    const is_demo: bool = buffer.is_demo_chunk(msg) catch return;
    if (!is_demo) return;
    var cleared_data = false;
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    const chunk_data: buffer.chunk_gen_data = switch (bd) {
        buffer.buffer_data.chunk_gen => |d| d,
        else => return,
    };
    errdefer if (!cleared_data) game.state.allocator.free(chunk_data.chunk_data);
    if (game.state.blocks.generated_settings_chunks.get(chunk_data.wp)) |data| {
        game.state.allocator.free(data);
        cleared_data = true;
    }
    game.state.blocks.generated_settings_chunks.put(chunk_data.wp, chunk_data.chunk_data) catch @panic("OOM");
    blecs.entities.screen.initDemoChunk();
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
    _ = game.state.jobs.load_chunks(ld.world_id, true);
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
        game.state.ui.world_chunk_table_data.put(lcd.wp_t, lcd.cfg_t) catch @panic("OOM");
        game.state.ui.world_chunk_table_data.put(lcd.wp_b, lcd.cfg_b) catch @panic("OOM");
    }
    if (!pr.done) return;
    if (!lcd.start_game) return;
    ui_helpers.loadChunksInWorld();
    screen_helpers.showGameScreen();
    ui_helpers.loadCharacterInWorld();
}

fn handle_terrain_gen(msg: buffer.buffer_message) void {
    const pr = buffer.progress_report(msg);
    const bd: buffer.buffer_data = buffer.get_data(msg) orelse return;
    const tg_d: buffer.terrain_gen_data = switch (bd) {
        buffer.buffer_data.terrain_gen => |d| d,
        else => return,
    };
    if (!pr.done) return;
    std.debug.print("terrain generated.\n", .{});
    const wp = chunk.worldPosition.initFromPositionV(tg_d.position);
    game.state.blocks.generated_settings_chunks.put(wp, tg_d.data) catch @panic("OOM");
    blecs.entities.screen.initDemoTerrainGen();
}

fn init_chunk_entity(world: *blecs.ecs.world_t, c: *chunk.Chunk) blecs.ecs.entity_t {
    const wp = c.wp;
    const p = wp.vecFromWorldPosition();
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
    var loc: @Vector(4, f32) = undefined;
    if (c.is_settings) {
        loc = .{ -32, 0, -32, 0 };
    } else {
        loc = .{
            p[0] * chunk.chunkDim,
            p[1] * chunk.chunkDim,
            p[2] * chunk.chunkDim,
            0,
        };
    }
    _ = blecs.ecs.set(world, chunk_entity, blecs.components.block.Chunk, .{
        .loc = loc,
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
