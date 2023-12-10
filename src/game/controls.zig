const zglfw = @import("zglfw");
const gl = @import("zopengl");
const state = @import("state.zig");

pub fn handleKey(window: *zglfw.Window, gameState: *state.State) !bool {
    if (window.getKey(.escape) == .press) {
        return true;
    }
    if (window.getKey(.q) == .press) {
        return true;
    }
    var direction: gl.Float = 1.0;
    if (window.getKey(.left_shift) == .press) {
        direction = -1.0;
    }
    if (window.getKey(.z) == .press) {
        gameState.zRotation += 1.0 * direction;
        if (gameState.zRotation > 360.0)
            gameState.zRotation = 0.0;
        return false;
    }
    if (window.getKey(.x) == .press) {
        gameState.xRotation += 1.0 * direction;
        if (gameState.xRotation > 360.0)
            gameState.xRotation = 0.0;
        return false;
    }
    if (window.getKey(.y) == .press) {
        gameState.yRotation += 1.0 * direction;
        if (gameState.yRotation > 360.0)
            gameState.yRotation = 0.0;
        return false;
    }

    return false;
}
