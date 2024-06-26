const system_name = "BlockPickingSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.mob.DidUpdate) };
    desc.run = if (config.use_tracy) runWithTrace else run;
    return desc;
}

fn runWithTrace(it: *ecs.iter_t) callconv(.C) void {
    ztracy.Message(system_name);
    const tracy_zone = ztracy.ZoneNC(@src(), system_name, 0xff_00_ff_f0);
    defer tracy_zone.End();
    return run(it);
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            selectBlock(world) catch |e| std.debug.panic("highlight block failed: {}\n", .{e});
        }
    }
}

fn selectBlock(world: *ecs.world_t) !void {
    const tpc = game.state.entities.third_person_camera;
    const player = game.state.entities.player;
    const wants_remove = ecs.has_id(world, player, ecs.id(components.mob.RemoveAction));
    if (wants_remove) ecs.remove(world, player, components.mob.RemoveAction);
    var wants_add = false;
    var new_block_id: u8 = 0;
    if (ecs.get(world, player, components.mob.AddAction)) |aa| {
        wants_add = true;
        new_block_id = aa.block_id;
    }
    if (wants_add) ecs.remove(world, player, components.mob.AddAction);
    if (!ecs.has_id(world, tpc, ecs.id(components.screen.CurrentCamera))) return;
    const cp: *const components.screen.CameraPosition = ecs.get(
        world,
        tpc,
        components.screen.CameraPosition,
    ) orelse return;
    const cf: *const components.screen.CameraFront = ecs.get(
        world,
        tpc,
        components.screen.CameraFront,
    ) orelse return;
    const camera_pos: @Vector(4, f32) = cp.pos;
    const ray_direction = zm.normalize3(cf.front);
    const step_size: f32 = 0.01;
    const max_distance: f32 = game.state.ui.block_picking_distance;
    var i: f32 = 5;
    var prev_pos: ?@Vector(4, f32) = null;
    while (i < max_distance) : (i += step_size) {
        const distance: @Vector(4, f32) = @splat(i);
        const pos: @Vector(4, f32) = camera_pos + ray_direction * distance;
        const res = chunk.getBlockId(pos);
        if (!res.read) return;
        const bd: block.BlockData = block.BlockData.fromId(res.data);
        if (bd.block_id != 0) {
            if (wants_remove) {
                removeBlock(world, pos);
                return;
            }
            if (wants_add and prev_pos != null) {
                addBlock(world, prev_pos.?, new_block_id);
            }
            highlightBlock(world, pos);
            return;
        }
        prev_pos = pos;
    }
}

fn highlightBlock(world: *ecs.world_t, pos: @Vector(4, f32)) void {
    const blh_e = game.state.entities.block_highlight;
    if (blh_e == 0 or !ecs.is_alive(world, blh_e)) return;
    var block_pos: @Vector(4, f32) = @floor(pos);
    block_pos[3] = 0;
    const wl = ecs.get_mut(
        world,
        blh_e,
        components.screen.WorldLocation,
    ) orelse return;
    if (@reduce(.And, wl.loc == block_pos)) {
        return;
    }
    var og_pos = wl.loc;
    og_pos[3] = 0;
    wl.loc = block_pos;
    ecs.add(world, blh_e, components.gfx.NeedsUniformUpdate);
    return;
}

fn removeBlock(world: *ecs.world_t, pos: @Vector(4, f32)) void {
    const cu_entity = ecs.new_id(world);
    _ = ecs.set(world, cu_entity, components.block.ChunkUpdate, .{ .pos = pos, .block_id = 0 });
    return;
}

fn addBlock(world: *ecs.world_t, pos: @Vector(4, f32), new_block_id: u8) void {
    const cu_entity = ecs.new_id(world);
    _ = ecs.set(world, cu_entity, components.block.ChunkUpdate, .{ .pos = pos, .block_id = new_block_id });
    return;
}

const std = @import("std");
const ecs = @import("zflecs");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const block = @import("../../../block/block.zig");
const chunk = block.chunk;
