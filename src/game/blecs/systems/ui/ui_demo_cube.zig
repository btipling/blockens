const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const gl = @import("zopengl").bindings;
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const entities = @import("../../entities/entities.zig");
const screen_helpers = @import("../../../screen/screen.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UIDemoCubeSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.DemoCube) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            zgui.setNextItemWidth(-1);
            if (zgui.begin("Demo Cube", .{
                .flags = .{},
            })) {
                if (zgui.inputFloat4("translation input", .{
                    .v = &game.state.ui.data.demo_cube_translation,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat4("translation slider", .{
                    .v = &game.state.ui.data.demo_cube_translation,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.inputFloat4("rotation input", .{
                    .v = &game.state.ui.data.demo_cube_rotation,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat4("rotation slider", .{
                    .v = &game.state.ui.data.demo_cube_rotation,
                    .min = -1,
                    .max = 1,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.inputFloat4("perspective translate input", .{
                    .v = &game.state.ui.data.demo_cube_pp_translation,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat4("perspective translate slider", .{
                    .v = &game.state.ui.data.demo_cube_pp_translation,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.inputFloat4("p1 pos input", .{
                    .v = &game.state.ui.data.demo_cube_plane_1_tl,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat4("p1 pos slider", .{
                    .v = &game.state.ui.data.demo_cube_plane_1_tl,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.inputFloat4("p2 pos input", .{
                    .v = &game.state.ui.data.demo_cube_plane_1_t2,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat4("p2 pos slider", .{
                    .v = &game.state.ui.data.demo_cube_plane_1_t2,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.inputFloat4("p3 pos input", .{
                    .v = &game.state.ui.data.demo_cube_plane_1_t3,
                })) {
                    entities.screen.initDemoCube();
                }
                if (zgui.sliderFloat4("p3 pos slider", .{
                    .v = &game.state.ui.data.demo_cube_plane_1_t3,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoCube();
                }
            }
            zgui.end();
        }
    }
}
