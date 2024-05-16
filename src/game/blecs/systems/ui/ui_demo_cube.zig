const system_name = "UIDemoCubeSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.DemoCube) };
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
            if (zgui.begin("Demo Cube", .{
                .flags = .{},
            })) {
                if (zgui.inputFloat4("translation input", .{
                    .v = &game.state.ui.demo_cube_translation,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat4("translation slider", .{
                    .v = &game.state.ui.demo_cube_translation,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.inputFloat4("rotation input", .{
                    .v = &game.state.ui.demo_cube_rotation,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat4("rotation slider", .{
                    .v = &game.state.ui.demo_cube_rotation,
                    .min = -1,
                    .max = 1,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.inputFloat4("perspective translate input", .{
                    .v = &game.state.ui.demo_cube_pp_translation,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat4("perspective translate slider", .{
                    .v = &game.state.ui.demo_cube_pp_translation,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.inputFloat4("p1 pos input", .{
                    .v = &game.state.ui.demo_cube_plane_1_tl,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat4("p1 pos slider", .{
                    .v = &game.state.ui.demo_cube_plane_1_tl,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.inputFloat4("p2 pos input", .{
                    .v = &game.state.ui.demo_cube_plane_1_t2,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat4("p2 pos slider", .{
                    .v = &game.state.ui.demo_cube_plane_1_t2,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.inputFloat4("p3 pos input", .{
                    .v = &game.state.ui.demo_cube_plane_1_t3,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat4("p3 pos slider", .{
                    .v = &game.state.ui.demo_cube_plane_1_t3,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.inputFloat4("atlas scale input", .{
                    .v = &game.state.ui.demo_atlas_scale,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat4("atlas scale slider", .{
                    .v = &game.state.ui.demo_atlas_scale,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.inputFloat4("atlas pos input", .{
                    .v = &game.state.ui.demo_atlas_translation,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat4("atlas pos slider", .{
                    .v = &game.state.ui.demo_atlas_translation,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.inputFloat("atlas rotation input", .{
                    .v = &game.state.ui.demo_atlas_rotation,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat("atlas rotation slider", .{
                    .v = &game.state.ui.demo_atlas_rotation,
                    .min = 0,
                    .max = 2,
                })) {
                    entities.screen.initDemoCube();
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
const entities = @import("../../entities/entities.zig");
const screen_helpers = @import("../screen_helpers.zig");
