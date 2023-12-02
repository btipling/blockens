const zglfw = @import("zglfw");

pub fn handleKey(window: *zglfw.Window) !bool {
    if (window.getKey(.escape) == .press) {
        return true;
    }
    if (window.getKey(.q) == .press) {
        return true;
    }

    return false;
}
