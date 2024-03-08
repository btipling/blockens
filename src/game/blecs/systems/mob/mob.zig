const setup = @import("mob_setup.zig");
const status = @import("mob_status.zig");

pub fn init() void {
    setup.init();
    status.init();
}
