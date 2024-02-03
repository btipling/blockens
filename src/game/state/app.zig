const gl = @import("zopengl");
const data = @import("../data/data.zig");
const screen = @import("screen.zig");

pub const App = struct {
    currentScreen: screen.Screens = screen.defaultScreen,
    previousScreen: screen.Screens = screen.defaultScreen,
    demoCubeVersion: u32 = 0,
    demoTextureColors: ?[data.RGBAColorTextureSize]gl.Uint,
    showChunkGeneratorUI: bool = true,

    pub fn init() !App {
        return App{
            .demoCubeVersion = 0,
            .demoTextureColors = null,
        };
    }

    pub fn toggleChunkGeneratorUI(self: *App) !void {
        self.showChunkGeneratorUI = !self.showChunkGeneratorUI;
    }

    pub fn clearScreenState(self: *App) !void {
        self.demoCubeVersion += 1;
        self.demoTextureColors = null;
    }

    pub fn setTextureColor(self: *App, demoTextureColors: [data.RGBAColorTextureSize]gl.Uint) void {
        self.demoTextureColors = demoTextureColors;
        self.demoCubeVersion += 1;
    }
};
