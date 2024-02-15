const zgui = @import("zgui");
const glfw = @import("zglfw");
const state = @import("../state/state.zig");
const components = @import("../blecs/components/components.zig");

pub const Game = struct {
    appState: *state.State,

    pub fn draw(self: Game, window: *glfw.Window, time: ?*components.Time) !void {
        try self.drawInfo(window, time);
    }

    fn drawInfo(self: Game, window: *glfw.Window, time: ?*components.Time) !void {
        window.setInputMode(glfw.InputMode.cursor, glfw.Cursor.Mode.disabled);
        const xPos: f32 = 50.0;
        const yPos: f32 = 50.0;
        zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
        zgui.setNextWindowSize(.{
            .w = 1500,
            .h = 200,
        });
        zgui.setNextItemWidth(-1);
        zgui.pushStyleColor4f(.{ .idx = .window_bg, .c = [_]f32{ 1.00, 1.00, 1.00, 0.25 } });
        zgui.pushStyleColor4f(.{ .idx = .text, .c = [_]f32{ 0.0, 0.0, 0.0, 1.00 } });
        if (zgui.begin("Hello, world!", .{
            .flags = .{
                .no_title_bar = true,
                .no_resize = true,
                .no_scrollbar = true,
                .no_collapse = true,
            },
        })) {
            var hours: i64 = 0;
            var minutes: i64 = 0;
            var seconds: i64 = 0;
            if (time) |t| {
                const duration = t.currentTime - t.startTime;
                const durSeconds = @divFloor(duration, 1000);
                const durMinutes = @divFloor(durSeconds, 60);
                hours = @divFloor(durMinutes, 60);
                minutes = @mod(durMinutes, 60);
                seconds = @mod(durSeconds, 60);
            }
            const h: u32 = @intCast(hours);
            const m: u32 = @intCast(minutes);
            const s: u32 = @intCast(seconds);
            zgui.text("Hello blockens! {d:0>2}:{d:0>2}:{d:0>2}", .{ h, m, s });
            zgui.text("F1 for settings", .{});
            const x: i32 = @intFromFloat(self.appState.demoScreen.cameraPos[0]);
            const y: i32 = @intFromFloat(self.appState.demoScreen.cameraPos[1]);
            const z: i32 = @intFromFloat(self.appState.demoScreen.cameraPos[2]);
            zgui.text("x: {d}, y: {d}, z: {d}.", .{ x, y, z });
            const cfX = self.appState.demoScreen.cameraFront[0];
            const cfY = self.appState.demoScreen.cameraFront[1];
            const cfZ = self.appState.demoScreen.cameraFront[2];
            zgui.text("cfX: {e:.2}, cfY: {e:.2}, cfZ: {e:.2}.", .{ cfX, cfY, cfZ });
            const yaw = self.appState.demoScreen.yaw;
            const pitch = self.appState.demoScreen.pitch;
            zgui.text("yaw: {e:.2}, pitch: {e:.2}.", .{ yaw, pitch });
        }
        zgui.end();
        zgui.popStyleColor(.{ .count = 2 });
    }
};
