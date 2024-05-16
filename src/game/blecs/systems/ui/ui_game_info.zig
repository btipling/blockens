const system_name = "UIGameInfoSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.GameInfo) };
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
    const world = game.state.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            if (ecs.has_id(world, game.state.entities.ui, ecs.id(components.ui.Menu))) continue;
            const current_camera = entities.screen.getCurrentCamera();
            const camera_front: *const components.screen.CameraFront = ecs.get(
                world,
                current_camera,
                components.screen.CameraFront,
            ) orelse continue;
            const camera_pos: *const components.screen.CameraPosition = ecs.get(
                world,
                current_camera,
                components.screen.CameraPosition,
            ) orelse continue;
            const camera_rot: *const components.screen.CameraRotation = ecs.get(
                world,
                current_camera,
                components.screen.CameraRotation,
            ) orelse continue;
            const time: *const components.Time = ecs.get(
                world,
                game.state.entities.clock,
                components.Time,
            ) orelse continue;
            const xPos: f32 = 0;
            const yPos: f32 = 0;
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = game.state.ui.screen_size[0],
                .h = game.state.ui.imguiHeight(50),
            });
            zgui.setNextItemWidth(-1);
            zgui.pushStyleColor4f(.{ .idx = .window_bg, .c = [_]f32{ 1.00, 1.00, 1.00, 0.25 } });
            zgui.pushStyleColor4f(.{ .idx = .text, .c = [_]f32{ 0.0, 0.0, 0.0, 1.00 } });
            if (zgui.begin("##GameInfo", .{
                .flags = .{
                    .no_title_bar = true,
                    .no_resize = true,
                    .no_scrollbar = true,
                    .no_collapse = true,
                },
            })) {
                var hours: i64 = 0;
                var minutes: i64 = 0;
                var seconds: i64 = 0;
                {
                    const duration = time.currentTime - time.startTime;
                    const durSeconds = @divFloor(duration, 1000);
                    const durMinutes = @divFloor(durSeconds, 60);
                    hours = @divFloor(durMinutes, 60);
                    minutes = @mod(durMinutes, 60);
                    seconds = @mod(durSeconds, 60);
                }
                const h: u32 = @intCast(hours);
                const m: u32 = @intCast(minutes);
                const s: u32 = @intCast(seconds);
                zgui.text("::BLOCKENS::[{d:0>2}:{d:0>2}:{d:0>2}] ", .{ h, m, s });
                zgui.sameLine(.{});
                zgui.text("[F1 settings] [F2 menu] ", .{});
                zgui.sameLine(.{});
                const x: i32 = @intFromFloat(camera_pos.pos[0]);
                const y: i32 = @intFromFloat(camera_pos.pos[1]);
                const z: i32 = @intFromFloat(camera_pos.pos[2]);
                zgui.text("[camera:{d},{d},{d}] ", .{ x, y, z });
                zgui.sameLine(.{});
                const yaw = camera_rot.yaw;
                const pitch = camera_rot.pitch;
                zgui.text("[yaw: {e:.2}] [pitch: {e:.2}] ", .{ yaw, pitch });

                zgui.sameLine(.{});
                const cfX = camera_front.front[0];
                const cfY = camera_front.front[1];
                const cfZ = camera_front.front[2];
                zgui.text("[front:{e:.2},{e:.2},{e:.2}] ", .{ cfX, cfY, cfZ });
                zgui.sameLine(.{});
                const fps: u32 = @intFromFloat((1 / (it.delta_time)));
                zgui.text("[fps:{d}]", .{fps});

                const pe = game.state.entities.player;
                const blh_e = game.state.entities.block_highlight;
                if (pe != 0 and ecs.is_alive(world, pe) and
                    blh_e != 0 and ecs.is_alive(world, blh_e))
                {
                    const mp: *const components.mob.Position = ecs.get(
                        world,
                        game.state.entities.player,
                        components.mob.Position,
                    ) orelse return;
                    const m_p = @floor(mp.position);
                    zgui.text("[player:{d},{d},{d}] ", .{ m_p[0], m_p[1], m_p[2] });

                    zgui.sameLine(.{});
                    zgui.text("[block id:{d}] ", .{game.state.blocks.selected_block});
                    zgui.sameLine(.{});
                    const wl: *const components.screen.WorldLocation = ecs.get(
                        world,
                        blh_e,
                        components.screen.WorldLocation,
                    ) orelse return;
                    const p = wl.loc;
                    zgui.text("[block:{d},{d},{d}] ", .{ p[0], p[1], p[2] });
                    zgui.sameLine(.{});
                    const c_bp = chunk.chunkBlockPosFromWorldLocation(p);
                    zgui.text("[chunk block:{d},{d},{d}]", .{ c_bp[0], c_bp[1], c_bp[2] });
                    zgui.sameLine(.{});
                    const c_p = chunk.worldPosition.positionFromWorldLocation(p);
                    zgui.text("[chunk pos:{d},{d},{d}]", .{ c_p[0], c_p[1], c_p[2] });
                }
            }
            zgui.end();
            zgui.popStyleColor(.{ .count = 2 });
        }
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
const block = @import("../../../block/block.zig");
const chunk = block.chunk;
