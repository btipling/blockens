const std = @import("std");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const config = @import("../config.zig");
const shape = @import("../shape/shape.zig");
const state = @import("../state.zig");
const data = @import("../data/data.zig");
const script = @import("../script/script.zig");

const maxWorldSizeName = 20;

pub const ChunkGenerator = struct {
    appState: *state.State,

    pub fn init(appState: *state.State, codeFont: zgui.Font, sc: script.Script, alloc: std.mem.Allocator) !ChunkGenerator {
        _ = sc;
        _ = alloc;
        _ = codeFont;
        const tv = ChunkGenerator{
            .appState = appState,
        };
        return tv;
    }

    pub fn deinit(self: *ChunkGenerator) void {
        _ = self;
    }

    pub fn draw(self: *ChunkGenerator, window: *glfw.Window) !void {
        if (!self.appState.app.showChunkGeneratorUI) {
            return;
        }
        const fb_size = window.getFramebufferSize();
        const w: u32 = @intCast(fb_size[0]);
        const h: u32 = @intCast(fb_size[1]);
        zgui.backend.newFrame(w, h);
        const xPos: f32 = 1700.0;
        const yPos: f32 = 50.0;
        zgui.setNextWindowFocus();
        zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
        zgui.setNextWindowSize(.{
            .w = 1850,
            .h = 2000,
        });
        zgui.setItemDefaultFocus();
        zgui.setNextItemWidth(-1);
        const style = zgui.getStyle();
        var window_bg = style.getColor(.window_bg);
        window_bg = .{ 1.00, 1.00, 1.00, 1.0 };
        style.setColor(.window_bg, window_bg);
        var text_color = style.getColor(.text);
        text_color = .{ 0.0, 0.0, 0.0, 1.00 };
        const title_color = .{ 1.0, 1.0, 1.0, 1.00 };
        style.setColor(.text, title_color);
        if (zgui.begin("Chunk Generator", .{
            .flags = .{
                .no_title_bar = false,
                .no_resize = true,
                .no_scrollbar = false,
                .no_collapse = true,
            },
        })) {
            try self.drawControls();
        }
        zgui.end();
        zgui.backend.draw();
    }

    fn drawControls(self: *ChunkGenerator) !void {
        if (zgui.beginChild(
            "Create World",
            .{
                .w = 850,
                .h = 1800,
                .border = false,
            },
        )) {
            zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
            const style = zgui.getStyle();
            var text_color = style.getColor(.text);
            text_color = .{ 0.0, 0.0, 0.0, 1.00 };
            style.setColor(.text, text_color);
            if (zgui.button("Generate random chunk", .{
                .w = 700,
                .h = 100,
            })) {
                try self.generateRandomChunk();
            }
            zgui.popStyleVar(.{ .count = 1 });
        }
        zgui.endChild();
    }

    fn generateRandomChunk(self: *ChunkGenerator) !void {
        _ = self;
        std.debug.print("Generating random chunk\n", .{});
    }
};
