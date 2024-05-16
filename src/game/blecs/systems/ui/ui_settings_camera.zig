const system_name = "UISettingsCameraSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.SettingsCamera) };
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
    var camera_p: *components.screen.CameraPosition = ecs.get_mut(
        game.state.world,
        game.state.entities.settings_camera,
        components.screen.CameraPosition,
    ) orelse return;
    _ = &camera_p;
    var camera_f: *components.screen.CameraFront = ecs.get_mut(
        game.state.world,
        game.state.entities.settings_camera,
        components.screen.CameraFront,
    ) orelse return;
    var camera_r: *components.screen.CameraRotation = ecs.get_mut(
        game.state.world,
        game.state.entities.settings_camera,
        components.screen.CameraRotation,
    ) orelse return;
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
            if (zgui.begin("Settings Camera", .{
                .flags = .{},
            })) {
                if (zgui.inputFloat4("pos input", .{ .v = &camera_p.pos })) {
                    ecs.add(
                        game.state.world,
                        game.state.entities.settings_camera,
                        components.screen.Updated,
                    );
                }
                if (zgui.sliderFloat4("pos slider", .{ .v = &camera_p.pos, .min = -10, .max = 10 })) {
                    ecs.add(
                        game.state.world,
                        game.state.entities.settings_camera,
                        components.screen.Updated,
                    );
                }
                if (zgui.inputFloat4("face input", .{ .v = &camera_f.front })) {
                    ecs.add(
                        game.state.world,
                        game.state.entities.settings_camera,
                        components.screen.Updated,
                    );
                }
                if (zgui.sliderFloat4("face slider", .{ .v = &camera_f.front, .min = -10, .max = 10 })) {
                    ecs.add(
                        game.state.world,
                        game.state.entities.settings_camera,
                        components.screen.Updated,
                    );
                }
                if (zgui.inputFloat("yaw input", .{ .v = &camera_r.yaw })) {
                    ecs.add(
                        game.state.world,
                        game.state.entities.settings_camera,
                        components.screen.Updated,
                    );
                }
                if (zgui.sliderFloat("yaw slider", .{ .v = &camera_r.yaw, .min = -10, .max = 10 })) {
                    ecs.add(
                        game.state.world,
                        game.state.entities.settings_camera,
                        components.screen.Updated,
                    );
                }
                if (zgui.inputFloat("pitch input", .{ .v = &camera_r.pitch })) {
                    ecs.add(
                        game.state.world,
                        game.state.entities.settings_camera,
                        components.screen.Updated,
                    );
                }
                if (zgui.sliderFloat("pitch slider", .{ .v = &camera_r.pitch, .min = -10, .max = 10 })) {
                    ecs.add(
                        game.state.world,
                        game.state.entities.settings_camera,
                        components.screen.Updated,
                    );
                }
            }
            zgui.end();
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
const game = @import("../../../game.zig");
const screen_helpers = @import("../screen_helpers.zig");
