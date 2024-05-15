pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UIDemoCharacterSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.DemoCharacter) };
    desc.run = run;
    return desc;
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
            if (zgui.begin("Demo Character", .{
                .flags = .{},
            })) {
                if (zgui.inputFloat4("translation input", .{
                    .v = &game.state.ui.demo_screen_translation,
                })) {
                    entities.screen.initDemoCharacterCamera(false);
                }
                if (zgui.sliderFloat4("translation slider", .{
                    .v = &game.state.ui.demo_screen_translation,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoCharacterCamera(false);
                }
                if (zgui.inputFloat("scale input", .{
                    .v = &game.state.ui.demo_screen_scale,
                })) {
                    entities.screen.initDemoCharacterCamera(false);
                }
                if (zgui.sliderFloat("scale slider", .{
                    .v = &game.state.ui.demo_screen_scale,
                    .min = 0,
                    .max = 1,
                })) {
                    entities.screen.initDemoCharacterCamera(false);
                }
                if (zgui.inputFloat("rotation input x", .{
                    .v = &game.state.ui.demo_screen_rotation_x,
                })) {
                    entities.screen.initDemoCharacterCamera(false);
                }
                if (zgui.sliderFloat("rotation slider x", .{
                    .v = &game.state.ui.demo_screen_rotation_x,
                    .min = -std.math.pi,
                    .max = std.math.pi,
                })) {
                    entities.screen.initDemoCharacterCamera(false);
                }
                if (zgui.inputFloat("rotation input y", .{
                    .v = &game.state.ui.demo_screen_rotation_y,
                })) {
                    entities.screen.initDemoCharacterCamera(false);
                }
                if (zgui.sliderFloat("rotation slider y", .{
                    .v = &game.state.ui.demo_screen_rotation_y,
                    .min = -std.math.pi,
                    .max = std.math.pi,
                })) {
                    entities.screen.initDemoCharacterCamera(false);
                }
                if (zgui.inputFloat("rotation input z", .{
                    .v = &game.state.ui.demo_screen_rotation_z,
                })) {
                    entities.screen.initDemoCharacterCamera(false);
                }
                if (zgui.sliderFloat("rotation slider z", .{
                    .v = &game.state.ui.demo_screen_rotation_z,
                    .min = -std.math.pi,
                    .max = std.math.pi,
                })) {
                    entities.screen.initDemoCharacterCamera(false);
                }
                if (zgui.inputFloat4("perspective translate input", .{
                    .v = &game.state.ui.demo_screen_pp_translation,
                })) {
                    entities.screen.initDemoCharacterCamera(false);
                }
                if (zgui.sliderFloat4("perspective translate slider", .{
                    .v = &game.state.ui.demo_screen_pp_translation,
                    .min = -1,
                    .max = 2,
                })) {
                    entities.screen.initDemoCharacterCamera(false);
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
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const entities = @import("../../entities/entities.zig");
const screen_helpers = @import("../screen_helpers.zig");
