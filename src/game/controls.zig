const zglfw = @import("zglfw");
const state = @import("state.zig");

pub fn handleKey(window: *zglfw.Window, gameState: *state.State) !bool {
    if (window.getKey(.escape) == .press) {
        return true;
    }
    if (window.getKey(.q) == .press) {
        return true;
    }
    if (window.getKey(.z) == .press) {
        gameState.zRotation += 1.0;
        if (gameState.zRotation > 360.0)
            gameState.zRotation = 0.0;
        return false;
    }
    if (window.getKey(.x) == .press) {
        gameState.xRotation += 1.0;
        if (gameState.xRotation > 360.0)
            gameState.xRotation = 0.0;
        return false;
    }
    if (window.getKey(.y) == .press) {
        gameState.yRotation += 1.0;
        if (gameState.yRotation > 360.0)
            gameState.yRotation = 0.0;
        return false;
    }

    return false;
}
