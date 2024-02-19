const std = @import("std");
const glfw = @import("zglfw");
const zgui = @import("zgui");
const game = @import("../game.zig");

const key_press_sensitivity_ms: i64 = 250;

pub fn pressedKey(key: glfw.Key) bool {
    return pressedKeys(@ptrCast(&[_]glfw.Key{key}), false);
}

pub fn holdKey(key: glfw.Key) bool {
    return pressedKeys(@ptrCast(&[_]glfw.Key{key}), true);
}

pub fn pressedKeys(keys: []const glfw.Key, hold: bool) bool {
    if (zgui.io.getWantCaptureKeyboard()) {
        return false;
    }
    const now = std.time.milliTimestamp();
    if (!hold) {
        if (now - game.state.input.last_key < key_press_sensitivity_ms) {
            return false;
        }
    }
    for (keys) |k| {
        if (game.state.window.getKey(k) != .press) {
            return false;
        }
    }
    game.state.input.last_key = now;
    return true;
}
