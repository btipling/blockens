const std = @import("std");
const ecs = @import("zflecs");
const gl = @import("zopengl").bindings;
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const chunk = @import("../../../chunk.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "BlockMeshingSystem", ecs.PreUpdate, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.block.Chunk) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.block.NeedsMeshing) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        for (0..it.count()) |i| {
            const entity = it.entities()[i];
            ecs.remove(world, entity, components.block.NeedsMeshing);
            var c: *chunk.Chunk = game.state.gfx.mesh_data.get(entity) orelse continue;
            _ = &c;
            _ = game.state.jobs.meshChunk(world, entity, c);
        }
    }
}
