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
const screen_helpers = @import("../../../screen/screen.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UIBlockEditorSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.BlockEditor) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = 700.0;
            const yPos: f32 = 50.0;
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = 2850,
                .h = 2000,
            });
            if (zgui.begin("Block Configuration", .{
                .flags = .{},
            })) {
                drawInput() catch |e| {
                    std.debug.print("error with input: {}\n", .{e});
                };
            }
            zgui.end();
        }
    }
}

fn drawInput() !void {
    if (zgui.beginChild(
        "script_input",
        .{
            .w = 2000,
            .h = 2000,
            .border = true,
        },
    )) {
        zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
        if (zgui.button("Do Something", .{
            .w = 450,
            .h = 100,
        })) {
            std.debug.print("did something\n", .{});
        }
        zgui.popStyleVar(.{ .count = 1 });
    }
    zgui.endChild();
}
