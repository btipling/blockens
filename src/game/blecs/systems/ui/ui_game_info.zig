const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const gl = @import("zopengl").bindings;
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UIGameInfoSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.GameInfo) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const camera_front: *const components.screen.CameraFront = ecs.get(
                game.state.world,
                game.state.entities.game_camera,
                components.screen.CameraFront,
            ) orelse continue;
            const camera_pos: *const components.screen.CameraPosition = ecs.get(
                game.state.world,
                game.state.entities.game_camera,
                components.screen.CameraPosition,
            ) orelse continue;
            const camera_rot: *const components.screen.CameraRotation = ecs.get(
                game.state.world,
                game.state.entities.game_camera,
                components.screen.CameraRotation,
            ) orelse continue;
            const time: *const components.Time = ecs.get(
                game.state.world,
                game.state.entities.clock,
                components.Time,
            ) orelse continue;
            const xPos: f32 = 50.0;
            const yPos: f32 = 50.0;
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = 1500,
                .h = 200,
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
                zgui.text("Hello blockens! {d:0>2}:{d:0>2}:{d:0>2}", .{ h, m, s });
                zgui.text("F1 for settings", .{});
                const x: i32 = @intFromFloat(camera_pos.pos[0]);
                const y: i32 = @intFromFloat(camera_pos.pos[1]);
                const z: i32 = @intFromFloat(camera_pos.pos[2]);
                zgui.text("x: {d}, y: {d}, z: {d}.", .{ x, y, z });
                const cfX = camera_front.front[0];
                const cfY = camera_front.front[1];
                const cfZ = camera_front.front[2];
                zgui.text("cfX: {e:.2}, cfY: {e:.2}, cfZ: {e:.2}.", .{ cfX, cfY, cfZ });
                const yaw = camera_rot.yaw;
                const pitch = camera_rot.pitch;
                zgui.text("yaw: {e:.2}, pitch: {e:.2}.", .{ yaw, pitch });
            }
            zgui.end();
            zgui.popStyleColor(.{ .count = 2 });
        }
    }
}
