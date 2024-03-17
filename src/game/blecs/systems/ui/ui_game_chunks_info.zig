const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const screen_helpers = @import("../screen_helpers.zig");
const chunk = @import("../../../chunk.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UIGameChunksInfoSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.GameChunksInfo) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            zgui.setNextItemWidth(-1);
            if (zgui.begin("Game Chunks Info", .{
                .flags = .{
                    .menu_bar = true,
                },
            })) {
                if (zgui.beginMenuBar()) {
                    if (zgui.menuItem("Close", .{})) {
                        screen_helpers.toggleGameChunksInfo();
                    }
                    zgui.endMenuBar();
                }
                zgui.text("Some chunks info here!", .{});
                showChunkList() catch unreachable;
            }
            zgui.end();
        }
    }
}

fn showChunkList() !void {
    if (zgui.beginTable(
        "Loaded Chunks",
        .{
            .flags = .{
                .resizable = true,
            },
            .column = 3,
            .outer_size = .{ 2000, 500 },
        },
    )) {
        const world = game.state.world;
        zgui.tableSetupColumn("Chunk Position", .{
            .flags = .{
                .no_resize = false,
            },
        });
        zgui.tableSetupColumn("Entity", .{});
        zgui.tableSetupColumn("Visibility", .{});
        zgui.tableHeadersRow();
        var it = game.state.gfx.game_chunks.iterator();
        while (it.next()) |kv| {
            const wp = kv.key_ptr.*;
            const c = kv.value_ptr.*;
            const entity = c.entity;
            const p = wp.vecFromWorldPosition();
            zgui.tableNextRow(.{});
            _ = zgui.tableSetColumnIndex(0);
            zgui.text("{d: >5}, {d: >5}, {d: >5}", .{
                p[0] * chunk.chunkDim,
                p[1] * chunk.chunkDim,
                p[2] * chunk.chunkDim,
            });
            _ = zgui.tableSetColumnIndex(1);
            zgui.text("{d}", .{entity});
            _ = zgui.tableSetColumnIndex(2);
            var is_drawn = false;
            const renderer_entity = ecs.get_target(world, entity, entities.block.HasChunkRenderer, 0);
            if (renderer_entity != 0) {
                if (ecs.has_id(world, renderer_entity, ecs.id(components.gfx.CanDraw))) {
                    is_drawn = true;
                }
            }
            if (is_drawn) {
                zgui.text("visible", .{});
            } else {
                zgui.text("hidden", .{});
            }
        }
        zgui.endTable();
    }
}
