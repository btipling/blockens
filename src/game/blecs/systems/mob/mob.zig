const setup = @import("mob_setup.zig");
const bb_setup = @import("mob_bb_setup.zig");
const jumping = @import("mob_jumping.zig");
const update = @import("mob_update.zig");
const falling = @import("mob_falling.zig");
const status = @import("mob_status.zig");
const save = @import("mob_save.zig");
const movement = @import("mob_movement.zig");

pub fn init() void {
    setup.init();
    bb_setup.init();
    jumping.init();
    movement.init();
    update.init();
    falling.init();
    status.init();
    save.init();
}
