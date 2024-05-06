pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UIDemoChunkSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.DemoChunk) };
    desc.run = run;
    return desc;
}

const preMaxChunk = struct {
    rotation_x: f32 = 0,
    rotation_y: f32 = 0.341,
    rotation_z: f32 = 0.083,
    scale: f32 = 0.042,
    translation: @Vector(4, f32) = @Vector(4, f32){ 2.55, 0.660, -0.264, 0 },
    pp_translation: @Vector(4, f32) = @Vector(4, f32){ -0.650, 0.100, 0, 0 },
};

var pre_max: preMaxChunk = .{};

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            zgui.setNextItemWidth(-1);
            if (zgui.begin("Demo Chunk", .{
                .flags = .{},
            })) {
                if (zgui.inputFloat4("translation input", .{
                    .v = &game.state.ui.demo_screen_translation,
                })) {
                    entities.screen.initDemoChunkCamera(false);
                }
                if (zgui.sliderFloat4("translation slider", .{
                    .v = &game.state.ui.demo_screen_translation,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoChunkCamera(false);
                }
                if (zgui.inputFloat("scale input", .{
                    .v = &game.state.ui.demo_screen_scale,
                })) {
                    entities.screen.initDemoChunkCamera(false);
                }
                if (zgui.sliderFloat("scale slider", .{
                    .v = &game.state.ui.demo_screen_scale,
                    .min = 0,
                    .max = 1,
                })) {
                    entities.screen.initDemoChunkCamera(false);
                }
                if (zgui.inputFloat("rotation input x", .{
                    .v = &game.state.ui.demo_screen_rotation_x,
                })) {
                    entities.screen.initDemoChunkCamera(false);
                }
                if (zgui.sliderFloat("rotation slider x", .{
                    .v = &game.state.ui.demo_screen_rotation_x,
                    .min = -std.math.pi,
                    .max = std.math.pi,
                })) {
                    entities.screen.initDemoChunkCamera(false);
                }
                if (zgui.inputFloat("rotation input y", .{
                    .v = &game.state.ui.demo_screen_rotation_y,
                })) {
                    entities.screen.initDemoChunkCamera(false);
                }
                if (zgui.sliderFloat("rotation slider y", .{
                    .v = &game.state.ui.demo_screen_rotation_y,
                    .min = -std.math.pi,
                    .max = std.math.pi,
                })) {
                    entities.screen.initDemoChunkCamera(false);
                }
                if (zgui.inputFloat("rotation input z", .{
                    .v = &game.state.ui.demo_screen_rotation_z,
                })) {
                    entities.screen.initDemoChunkCamera(false);
                }
                if (zgui.sliderFloat("rotation slider z", .{
                    .v = &game.state.ui.demo_screen_rotation_z,
                    .min = -std.math.pi,
                    .max = std.math.pi,
                })) {
                    entities.screen.initDemoChunkCamera(false);
                }
                if (zgui.inputFloat4("perspective translate input", .{
                    .v = &game.state.ui.demo_screen_pp_translation,
                })) {
                    entities.screen.initDemoChunkCamera(false);
                }
                if (zgui.sliderFloat4("perspective translate slider", .{
                    .v = &game.state.ui.demo_screen_pp_translation,
                    .min = -1,
                    .max = 2,
                })) {
                    entities.screen.initDemoChunkCamera(false);
                }
                if (zgui.button("max", .{
                    .h = 50,
                    .w = 250,
                })) {
                    pre_max = .{
                        .rotation_x = game.state.ui.demo_screen_rotation_x,
                        .rotation_y = game.state.ui.demo_screen_rotation_y,
                        .rotation_z = game.state.ui.demo_screen_rotation_z,
                        .scale = game.state.ui.demo_screen_scale,
                        .translation = game.state.ui.demo_screen_translation,
                        .pp_translation = game.state.ui.demo_screen_pp_translation,
                    };
                    game.state.ui.demo_screen_rotation_x = 0;
                    game.state.ui.demo_screen_rotation_y = pre_max.rotation_y;
                    game.state.ui.demo_screen_rotation_z = 1.085;
                    game.state.ui.demo_screen_scale = 0.107;
                    game.state.ui.demo_screen_translation = .{ 4.449, -1.631, -0.264, 0 };
                    game.state.ui.demo_screen_pp_translation = .{ 0, 0, 0, 0 };
                    entities.screen.initDemoChunkCamera(false);
                }
                zgui.sameLine(.{});
                if (zgui.button("unmax", .{
                    .h = 50,
                    .w = 250,
                })) {
                    game.state.ui.demo_screen_rotation_x = pre_max.rotation_x;
                    game.state.ui.demo_screen_rotation_y = pre_max.rotation_y;
                    game.state.ui.demo_screen_rotation_z = pre_max.rotation_z;
                    game.state.ui.demo_screen_scale = pre_max.scale;
                    game.state.ui.demo_screen_translation = pre_max.translation;
                    game.state.ui.demo_screen_pp_translation = pre_max.pp_translation;
                    entities.screen.initDemoChunkCamera(false);
                }
                zgui.sameLine(.{});
                if (zgui.button("debug", .{
                    .h = 50,
                    .w = 250,
                })) {
                    game.state.ui.demo_screen_rotation_x = 0;
                    game.state.ui.demo_screen_rotation_y = 0.341;
                    game.state.ui.demo_screen_rotation_z = 0.938;
                    game.state.ui.demo_screen_scale = 0.107;
                    game.state.ui.demo_screen_translation = .{ -1.718, -1.631, -0.264, 0 };
                    game.state.ui.demo_screen_pp_translation = .{ -0.650, 0.100, 0.000, 0 };
                    entities.screen.initDemoChunkCamera(false);
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
