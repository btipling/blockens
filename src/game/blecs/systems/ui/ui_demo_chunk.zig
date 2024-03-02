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
    ecs.SYSTEM(game.state.world, "UIDemoChunkSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.ui.DemoChunk) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            zgui.setNextItemWidth(-1);
            if (zgui.begin("Demo Chunk", .{
                .flags = .{},
            })) {
                if (zgui.inputFloat4("translation input", .{
                    .v = &game.state.ui.data.demo_chunk_translation,
                })) {
                    entities.screen.initDemoChunk();
                }
                if (zgui.sliderFloat4("translation slider", .{
                    .v = &game.state.ui.data.demo_chunk_translation,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoChunk();
                }
                if (zgui.inputFloat("scale input", .{
                    .v = &game.state.ui.data.demo_chunk_scale,
                })) {
                    entities.screen.initDemoChunk();
                }
                if (zgui.sliderFloat("scale slider", .{
                    .v = &game.state.ui.data.demo_chunk_scale,
                    .min = 0,
                    .max = 0.09,
                })) {
                    entities.screen.initDemoChunk();
                }
                if (zgui.inputFloat("rotation input x", .{
                    .v = &game.state.ui.data.demo_chunk_rotation_x,
                })) {
                    entities.screen.initDemoChunk();
                }
                if (zgui.sliderFloat("rotation slider x", .{
                    .v = &game.state.ui.data.demo_chunk_rotation_x,
                    .min = 0,
                    .max = 2,
                })) {
                    entities.screen.initDemoChunk();
                }
                if (zgui.inputFloat("rotation input y", .{
                    .v = &game.state.ui.data.demo_chunk_rotation_y,
                })) {
                    entities.screen.initDemoChunk();
                }
                if (zgui.sliderFloat("rotation slider y", .{
                    .v = &game.state.ui.data.demo_chunk_rotation_y,
                    .min = 0,
                    .max = 2,
                })) {
                    entities.screen.initDemoChunk();
                }
                if (zgui.inputFloat("rotation input z", .{
                    .v = &game.state.ui.data.demo_chunk_rotation_z,
                })) {
                    entities.screen.initDemoChunk();
                }
                if (zgui.sliderFloat("rotation slider z", .{
                    .v = &game.state.ui.data.demo_chunk_rotation_z,
                    .min = 0,
                    .max = 2,
                })) {
                    entities.screen.initDemoChunk();
                }
                if (zgui.inputFloat4("perspective translate input", .{
                    .v = &game.state.ui.data.demo_chunk_pp_translation,
                })) {
                    entities.screen.initDemoChunk();
                }
                if (zgui.sliderFloat4("perspective translate slider", .{
                    .v = &game.state.ui.data.demo_chunk_pp_translation,
                    .min = -10,
                    .max = 10,
                })) {
                    entities.screen.initDemoChunk();
                }
            }
            zgui.end();
        }
    }
}
