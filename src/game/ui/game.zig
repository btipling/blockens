const zgui = @import("zgui");
const glfw = @import("zglfw");
const state = @import("../state.zig");

pub const Game = struct {
    appState: *state.State,

    pub fn draw(self: Game, window: *glfw.Window) !void {
        try self.drawInfo(window);
    }

    fn drawInfo(self: Game, window: *glfw.Window) !void {
        window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);
        const xPos: f32 = 50.0;
        const yPos: f32 = 50.0;
        zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
        zgui.setNextWindowSize(.{
            .w = 1500,
            .h = 200,
        });
        zgui.setNextItemWidth(-1);
        zgui.pushStyleColor4f(.{ .idx = .window_bg, .c = [_]f32{ 1.00, 1.00, 1.00, 1.0 } });
        zgui.pushStyleColor4f(.{ .idx = .text, .c = [_]f32{ 0.0, 0.0, 0.0, 1.00 } });
        if (zgui.begin("Hello, world!", .{
            .flags = .{
                .no_title_bar = true,
                .no_resize = true,
                .no_scrollbar = true,
                .no_collapse = true,
            },
        })) {
            zgui.text("Hello btzig-blockens!", .{});
            zgui.text("F1 for settings", .{});
            const x = @as(i32, @intFromFloat(self.appState.worldView.cameraPos[0]));
            const y = @as(i32, @intFromFloat(self.appState.worldView.cameraPos[1]));
            const z = @as(i32, @intFromFloat(self.appState.worldView.cameraPos[2]));
            zgui.text("x: {d}, y: {d}, z: {d}.", .{ x, y, z });
            const cfX = self.appState.worldView.cameraFront[0];
            const cfY = self.appState.worldView.cameraFront[1];
            const cfZ = self.appState.worldView.cameraFront[2];
            zgui.text("cfX: {e:.2}, cfY: {e:.2}, cfZ: {e:.2}.", .{ cfX, cfY, cfZ });
            const yaw = self.appState.worldView.yaw;
            const pitch = self.appState.worldView.pitch;
            zgui.text("yaw: {e:.2}, pitch: {e:.2}.", .{ yaw, pitch });
            zgui.sameLine(.{});
            zgui.text("meshChunks: {}.", .{self.appState.worldView.meshChunks});
        }
        zgui.end();
        zgui.popStyleColor(.{ .count = 2 });
    }
};
