const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.gfx.BaseRenderer) };
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const br: []components.gfx.BaseRenderer = ecs.field(it, components.gfx.BaseRenderer, 1) orelse return;
            gl.clear(br[i].clear);

            gl.clearBufferfv(gl.COLOR, 0, &br[i].bgColor.arr);
        }
    }
}
