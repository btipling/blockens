const system_name = "UICharacterEditorSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.CharacterEditor) };
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
            const xPos: f32 = game.state.ui.imguiX(1100);
            const yPos: f32 = game.state.ui.imguiY(25);
            zgui.setNextWindowPos(.{
                .x = xPos,
                .y = yPos,
                .cond = .first_use_ever,
            });
            zgui.setNextWindowSize(.{
                .w = game.state.ui.imguiWidth(800),
                .h = game.state.ui.imguiHeight(1000),
                .cond = .first_use_ever,
            });
            zgui.setNextItemWidth(-1);
            if (zgui.begin("Character Designer", .{
                .flags = .{},
            })) {
                drawControls() catch continue;
            }
            zgui.end();
        }
    }
}

fn drawControls() !void {
    const btn_dms: [2]f32 = game.state.ui.imguiButtonDims();
    if (zgui.beginChild(
        "Controls",
        .{
            .w = game.state.ui.imguiWidth(305),
            .h = game.state.ui.imguiHeight(900),
            .border = true,
        },
    )) {
        zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = game.state.ui.imguiPadding() });
        if (zgui.button("Generate character", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try generateCharacter();
        }
        if (zgui.button("Toggle walking", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try toggleWalking();
        }
        if (zgui.button("Toggle Bounding Box", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try toggleBoundingBox();
        }
        if (zgui.button("Toggle Wireframe", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            toggleWireframe();
        }
        zgui.popStyleVar(.{ .count = 1 });
    }
    zgui.endChild();
}

fn generateCharacter() !void {
    entities.screen.initDemoCharacter();
}

fn toggleWalking() !void {
    if (ecs.has_id(game.state.world, game.state.entities.demo_player, ecs.id(components.mob.Walking))) {
        ecs.remove(game.state.world, game.state.entities.demo_player, components.mob.Walking);
        return;
    }
    ecs.add(game.state.world, game.state.entities.demo_player, components.mob.Walking);
}

fn toggleBoundingBox() !void {
    const world = game.state.world;
    const player = game.state.entities.demo_player;

    const bounding_box = ecs.get_target(world, player, entities.mob.HasBoundingBox, 0);
    if (bounding_box != 0) {
        if (ecs.has_id(world, bounding_box, ecs.id(components.gfx.ManuallyHidden))) {
            ecs.remove(world, bounding_box, components.gfx.ManuallyHidden);
            return;
        }
        ecs.add(world, bounding_box, components.gfx.ManuallyHidden);
        return;
    }
}

fn toggleWireframe() void {
    const screen: *const components.screen.Screen = ecs.get(
        game.state.world,
        game.state.entities.screen,
        components.screen.Screen,
    ) orelse return;
    screen_helpers.toggleWireframe(screen.current);
}

const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const helpers = @import("../../helpers.zig");
const game = @import("../../../game.zig");
const screen_helpers = @import("../screen_helpers.zig");
