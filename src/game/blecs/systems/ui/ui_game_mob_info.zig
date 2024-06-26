const system_name = "UIGameMobInfoSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.GameMobInfo) };
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
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = game.state.ui.imguiX(100);
            const yPos: f32 = game.state.ui.imguiY(100);
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .first_use_ever });
            zgui.setNextWindowSize(.{
                .w = game.state.ui.imguiWidth(600),
                .h = game.state.ui.imguiHeight(685),
                .cond = .first_use_ever,
            });
            if (zgui.begin("Game Mob Info", .{
                .flags = .{
                    .menu_bar = true,
                },
            })) {
                if (zgui.beginMenuBar()) {
                    if (zgui.menuItem("Close", .{})) {
                        screen_helpers.toggleGameMobInfo();
                    }
                    zgui.endMenuBar();
                }
                showMobActions() catch @panic("nope");
            }
            zgui.end();
        }
    }
}

fn showMobActions() !void {
    if (zgui.button("Toggle Bounding Box", .{
        .w = 600,
        .h = 100,
    })) {
        toggleBoundingBox();
    }
    if (zgui.inputFloat4("Set location", .{
        .v = &game.state.ui.world_player_relocation,
    })) {
        std.debug.print("player relocation updated.\n", .{});
    }
    if (zgui.inputFloat("Set block picking distance", .{
        .v = &game.state.ui.block_picking_distance,
    })) {
        std.debug.print("player block picking distance updated.\n", .{});
    }
    if (zgui.button("Relocate Player", .{
        .w = 600,
        .h = 100,
    })) {
        relocatePlayer();
    }
    if (zgui.button("Move to Origin", .{
        .w = 600,
        .h = 100,
    })) {
        movePlayerToOrigin();
    }
}

fn toggleBoundingBox() void {
    const world = game.state.world;
    const player = game.state.entities.player;

    const bounding_box = ecs.get_target(world, player, entities.mob.HasBoundingBox, 0);
    if (bounding_box != 0) {
        std.debug.print("player has a bounding box\n", .{});
        if (ecs.has_id(world, bounding_box, ecs.id(components.gfx.ManuallyHidden))) {
            ecs.remove(world, bounding_box, components.gfx.ManuallyHidden);
            return;
        }
        ecs.add(world, bounding_box, components.gfx.ManuallyHidden);
        return;
    }
    std.debug.print("player doesn't have a bounding box?\n", .{});
}

fn relocatePlayer() void {
    var position: *components.mob.Position = ecs.get_mut(
        game.state.world,
        game.state.entities.player,
        components.mob.Position,
    ) orelse return;
    position.position = game.state.ui.world_player_relocation;
    ecs.add(game.state.world, game.state.entities.player, components.mob.NeedsUpdate);
}

fn movePlayerToOrigin() void {
    var position: *components.mob.Position = ecs.get_mut(
        game.state.world,
        game.state.entities.player,
        components.mob.Position,
    ) orelse return;
    position.position = .{ 32, 64, 32, 1 };
    ecs.add(game.state.world, game.state.entities.player, components.mob.NeedsUpdate);
}

const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const screen_helpers = @import("../screen_helpers.zig");
const block = @import("../../../block/block.zig");
const chunk = block.chunk;
