const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const gl = @import("zopengl").bindings;
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const data = @import("../../../data/data.zig");
const script = @import("../../../script/script.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UICharacterEditorSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.CharacterEditor) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = 2200.0;
            const yPos: f32 = 50.0;
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = 1600,
                .h = 2000,
            });
            zgui.setNextItemWidth(-1);
            if (zgui.begin("Character Designer", .{
                .flags = .{
                    .no_title_bar = false,
                    .no_resize = false,
                    .no_scrollbar = false,
                    .no_collapse = false,
                },
            })) {
                drawControls() catch unreachable;
            }
            zgui.end();
        }
    }
}

fn drawControls() !void {
    if (zgui.beginChild(
        "Saved Worlds",
        .{
            .w = 510,
            .h = 2100,
            .border = true,
        },
    )) {
        zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
        if (zgui.button("Generate character", .{
            .w = 500,
            .h = 100,
        })) {
            try generateCharacter();
        }
        if (zgui.button("Toggle walking", .{
            .w = 500,
            .h = 100,
        })) {
            try toggleWalking();
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
