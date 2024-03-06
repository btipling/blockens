const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl").bindings;
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const cltf_mesh = @import("../../../shape/gfx/cltf_mesh.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "MobSetupSystem", ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.mob.Mob) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.mob.NeedsSetup) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            std.debug.print("MobSetupSystem\n", .{});
            const entity = it.entities()[i];
            const m: []components.mob.Mob = ecs.field(it, components.mob.Mob, 1) orelse return;
            ecs.remove(world, entity, components.mob.NeedsSetup);
            std.debug.print("creating mob {d}\n", .{m[i].mob_id});
            var cm = cltf_mesh.Mesh.init(m[i].mob_id) catch unreachable;
            defer cm.deinit();
            cm.build() catch unreachable;
            std.debug.print("done creating mob {d}\n", .{m[i].mob_id});
        }
    }
}
