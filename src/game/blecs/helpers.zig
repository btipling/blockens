const ecs = @import("zflecs");

pub fn new_child(world: *ecs.world_t, parent: ecs.entity_t) ecs.entity_t {
    return new_w_pair(world, ecs.ChildOf, parent);
}

// ecs_new_w_pair
pub fn new_w_pair(world: *ecs.world_t, first: ecs.entity_t, second: ecs.entity_t) ecs.entity_t {
    const pair_id = ecs.make_pair(first, second);
    return ecs.new_w_id(world, pair_id);
}

// ecs_delete_children
pub fn delete_children(world: *ecs.world_t, parent: ecs.entity_t) void {
    ecs.delete_with(world, ecs.make_pair(ecs.ChildOf, parent));
}
