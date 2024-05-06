pub fn init() void {
    hotkeys.init();
}

const hotkeys = @import("settings_hotkeys.zig");
