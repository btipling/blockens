const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl").bindings;
const glfw = @import("zglfw");
const components = @import("../../../components/components.zig");
const game = @import("../../../../game.zig");
const input = @import("../../../../input/input.zig");

var pressedKeyState: ?glfw.Key = null;

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "GameCursorSystem", ecs.OnLoad, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.Cursor) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.screen.Updated) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            std.debug.print("mouse moved.\n", .{});
            ecs.remove(world, entity, components.screen.Updated);
        }
    }
}
