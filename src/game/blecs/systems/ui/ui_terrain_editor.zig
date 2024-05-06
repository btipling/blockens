const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const helpers = @import("../../helpers.zig");
const game = @import("../../../game.zig");
const data = @import("../../../data/data.zig");
const script = @import("../../../script/script.zig");
const screen_helpers = @import("../screen_helpers.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UITerrainEditorSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.TerrainEditor) };
    desc.run = run;
    return desc;
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
            if (zgui.begin("Terrain Generator", .{
                .flags = .{},
            })) {
                drawControls() catch continue;
            }
            zgui.end();
        }
    }
}

fn drawControls() !void {
    const btn_dims: [2]f32 = game.state.ui.imguiButtonDims();
    if (zgui.beginChild(
        "Controls",
        .{},
    )) {
        zgui.text("terrain generator controls", .{});
        if (zgui.button("generate terrain", .{
            .w = btn_dims[0],
            .h = btn_dims[1],
        })) {
            _ = game.state.jobs.generateTerrain(
                game.state.ui.terrain_gen_x_buf,
                game.state.ui.terrain_gen_z_buf,
            );
        }
    }
    zgui.endChild();
}
