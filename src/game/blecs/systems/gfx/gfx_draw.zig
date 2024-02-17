const std = @import("std");
const ecs = @import("zflecs");
const zmesh = @import("zmesh");
const tags = @import("../../tags.zig");
const components = @import("../../components/components.zig");

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.gfx.ElementsRenderer) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.gfx.CanDraw) };
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const ers: []components.gfx.ElementsRenderer = ecs.field(it, components.gfx.ElementsRenderer, 1) orelse return;
            std.debug.print("CanDraw: {d}\n", .{ers.len});
        }
    }
}