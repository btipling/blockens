const std = @import("std");
const ecs = @import("zflecs");
const tags = @import("../../tags.zig");
const components = @import("../../components/components.zig");

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(tags.Hud) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.shape.Plane) };
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const planes: []components.shape.Plane = ecs.field(it, components.shape.Plane, 2) orelse return;
            if (planes.len > 1) {
                std.debug.print("num planes: {d}\n", .{planes.len});
            }
        }
    }
}
