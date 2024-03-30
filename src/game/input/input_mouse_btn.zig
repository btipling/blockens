const std = @import("std");
const glfw = @import("zglfw");
const zgui = @import("zgui");
const blecs = @import("../blecs/blecs.zig");
const game = @import("../game.zig");

pub fn mouseBtnCallback(_: *glfw.Window, btn: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    handleMouseBtn(btn, action, mods) catch |e| {
        std.debug.print("mouse button error {}\n", .{e});
    };
}

fn handleMouseBtn(btn: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) !void {
    if (zgui.io.getWantCaptureMouse()) return;
    const world = game.state.world;
    const screen = game.state.entities.screen;
    const sc = blecs.ecs.get(world, screen, blecs.components.screen.Screen) orelse return;
    if (blecs.ecs.has_id(world, sc.current, blecs.ecs.id(blecs.components.screen.Game))) {
        return try handleGameMouseBtn(btn, action, mods);
    }
}

fn handleGameMouseBtn(btn: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) !void {
    std.debug.print("handled mouse button in game {}, {}, {}\n", .{ btn, action, mods });
}
