const system_name = "UIGameChunksInfoSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.GameChunksInfo) };
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

                _ = zgui.checkbox("Wire frame mode", .{
                    .v = &game.state.ui.gfx_wire_frames,
                });
                _ = zgui.checkbox("Lock cull from player position", .{
                    .v = &game.state.ui.gfx_lock_cull_to_player_pos,
                });
                _ = zgui.checkbox("Cull with aabb trees", .{
                    .v = &game.state.ui.gfx_use_aabb_chull,
                });
                showChunkList() catch continue;
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
            .column = 4,
            .outer_size = .{
                game.state.ui.imguiWidth(1000),
                game.state.ui.imguiHeight(250),
            },
        },
    )) {
        const world = game.state.world;
        zgui.tableSetupColumn("Chunk Position", .{
            .flags = .{},
        });
        zgui.tableSetupColumn("Entity", .{});
        zgui.tableSetupColumn("Visibility", .{});
        zgui.tableSetupColumn("Toggle", .{});
        zgui.tableHeadersRow();
        var it = game.state.blocks.game_chunks.iterator();
        var i: usize = 0;
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
            var hidden = false;
            const renderer_entity = ecs.get_target(world, entity, entities.block.HasChunkRenderer, 0);
            if (renderer_entity != 0) {
                const can_draw = ecs.has_id(world, renderer_entity, ecs.id(components.gfx.CanDraw));
                if (can_draw) {
                    is_drawn = true;
                }
                hidden = ecs.has_id(world, renderer_entity, ecs.id(components.gfx.ManuallyHidden));
                if (hidden) {
                    is_drawn = false;
                }
            }
            if (is_drawn) {
                zgui.text("visible", .{});
            } else {
                zgui.text("hidden", .{});
            }
            if (zgui.tableSetColumnIndex(3)) {
                var buffer: [50]u8 = undefined;
                const btn_label: [:0]u8 = try std.fmt.bufPrintZ(&buffer, "toggle##{d}", .{i});
                if (zgui.smallButton(btn_label)) {
                    if (renderer_entity != 0) {
                        if (hidden) {
                            ecs.remove(world, renderer_entity, components.gfx.ManuallyHidden);
                        } else {
                            ecs.add(world, renderer_entity, components.gfx.ManuallyHidden);
                        }
                    }
                }
            }
            i += 1;
        }
        zgui.endTable();
    }
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
