const setup = @import("mob_setup.zig");
const update = @import("mob_update.zig");
const status = @import("mob_status.zig");

pub fn init() void {
    setup.init();
    update.init();
    status.init();
}
