const std = @import("std");
const glfw = @import("zglfw");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const zm = @import("zmath");
const zgui = @import("zgui");
const data = @import("../data/data.zig");
const script = @import("../script/script.zig");

pub const Entities = struct {
    screen: usize = 0,
    clock: usize = 0,
    gfx: usize = 0,
    sky: usize = 0,
    floor: usize = 0,
    crosshair: usize = 0,
    menu: usize = 0,
    game_camera: usize = 0,
    settings_camera: usize = 0,
    wall: usize = 0,
    ui: usize = 0,
};

pub const Cursor = struct {
    last_x: gl.Float = 0,
    last_y: gl.Float = 0,
};

pub const Input = struct {
    last_key: i64 = 0,
    cursor: ?Cursor = null,
    lastframe: gl.Float = 0,
    delta_time: gl.Float = 0,
};

pub const UIData = struct {
    texture_script_options: std.ArrayList(data.scriptOption) = undefined,
    texture_loaded_script_id: i32 = 0,
    texture_buf: [script.maxLuaScriptSize]u8 = [_]u8{0} ** script.maxLuaScriptSize,
    texture_name_buf: [script.maxLuaScriptNameSize]u8 = [_]u8{0} ** script.maxLuaScriptNameSize,
    texture_rgba_data: ?[]gl.Uint = null,
    demo_cube_rotation: @Vector(4, gl.Float) = zm.matToQuat(zm.rotationY(0.25 * std.math.pi)),
    demo_cube_translation: @Vector(4, gl.Float) = @Vector(4, gl.Float){ 0, 0, 2.5, 0 },

    fn deinit(self: *UIData, allocator: std.mem.Allocator) void {
        self.texture_script_options.deinit();
        if (self.texture_rgba_data) |d| allocator.free(d);
    }
};

pub const UI = struct {
    gameFont: zgui.Font = undefined,
    codeFont: zgui.Font = undefined,
    data: *UIData = undefined,
};

pub const ElementsRendererConfig = struct {
    vertexShader: [:0]const u8 = undefined,
    fragmentShader: [:0]const u8 = undefined,
    positions: [][3]gl.Float = undefined,
    indices: []u32 = undefined,
    texcoords: ?[][2]gl.Float = null,
    normals: ?[][3]gl.Float = null,
    transform: ?zm.Mat = null,
    ubo_binding_point: ?gl.Uint = null,
    has_demo_cube_texture: bool = false,
};

pub const Gfx = struct {
    ubos: std.AutoHashMap(gl.Uint, gl.Uint) = undefined,
    renderConfigs: std.AutoHashMap(ecs.entity_t, *ElementsRendererConfig) = undefined,
};

pub const Game = struct {
    allocator: std.mem.Allocator = undefined,
    window: *glfw.Window = undefined,
    world: *ecs.world_t = undefined,
    db: data.Data = undefined,
    script: script.Script = undefined,
    entities: Entities = .{},
    input: Input = .{},
    ui: UI = .{},
    gfx: Gfx = .{},
    quit: bool = false,

    pub fn initInternals(self: *Game) !void {
        try self.initDb();
        try self.initScript();
        try self.initUIData();
    }

    pub fn deinit(self: *Game) void {
        self.gfx.ubos.deinit();
        var cfgs = self.gfx.renderConfigs.valueIterator();
        while (cfgs.next()) |rcfg| {
            self.allocator.destroy(rcfg);
        }
        self.gfx.renderConfigs.deinit();
        self.script.deinit();
        self.db.deinit();
        self.ui.data.deinit(self.allocator);
        self.allocator.destroy(self.ui.data);
    }

    pub fn initDb(self: *Game) !void {
        self.db = try data.Data.init(self.allocator);
        self.db.ensureSchema() catch |err| {
            std.log.err("Failed to ensure schema: {}\n", .{err});
            return err;
        };
        self.db.ensureDefaultWorld() catch |err| {
            std.log.err("Failed to ensure default world: {}\n", .{err});
            return err;
        };
    }

    pub fn initUIData(self: *Game) !void {
        self.ui.data = try self.allocator.create(UIData);
        self.ui.data.* = UIData{
            .texture_script_options = std.ArrayList(data.scriptOption).init(self.allocator),
        };
    }

    pub fn initScript(self: *Game) !void {
        self.script = try script.Script.init(self.allocator);
    }
};
