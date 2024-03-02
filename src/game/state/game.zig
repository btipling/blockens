const std = @import("std");
const glfw = @import("zglfw");
const blecs = @import("../blecs/blecs.zig");
const gl = @import("zopengl").bindings;
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
    block_options: std.ArrayList(data.blockOption) = undefined,
    block_create_name_buf: [data.maxBlockSizeName]u8 = [_]u8{0} ** data.maxBlockSizeName,
    block_update_name_buf: [data.maxBlockSizeName]u8 = [_]u8{0} ** data.maxBlockSizeName,
    block_loaded_block_id: i32 = 0,
    chunk_name_buf: [script.maxLuaScriptNameSize]u8 = [_]u8{0} ** script.maxLuaScriptNameSize,
    chunk_buf: [script.maxLuaScriptSize]u8 = [_]u8{0} ** script.maxLuaScriptSize,
    chunk_x_buf: [5]u8 = [_]u8{0} ** 5,
    chunk_y_buf: [5]u8 = [_]u8{0} ** 5,
    chunk_z_buf: [5]u8 = [_]u8{0} ** 5,
    chunk_script_options: std.ArrayList(data.chunkScriptOption) = undefined,
    chunk_loaded_script_id: i32 = 0,
    chunk_script_color: [3]f32 = [_]f32{0} ** 3,
    chunk_demo_data: ?[]i32 = null,
    demo_cube_rotation: @Vector(4, gl.Float) = zm.matToQuat(zm.rotationY(0 * std.math.pi)),
    demo_cube_translation: @Vector(4, gl.Float) = @Vector(4, gl.Float){ 0, 0, 0, 0 },
    demo_cube_pp_translation: @Vector(4, gl.Float) = @Vector(4, gl.Float){ -0.825, 0.650, 0, 0 },
    demo_cube_plane_1_tl: @Vector(4, gl.Float) = @Vector(4, gl.Float){ -0.926, 0.12, 0, 0 },
    demo_cube_plane_1_t2: @Vector(4, gl.Float) = @Vector(4, gl.Float){ -0.727, 0.090, 0, 0 },
    demo_cube_plane_1_t3: @Vector(4, gl.Float) = @Vector(4, gl.Float){ -0.926, -0.54, 0, 0 },

    fn deinit(self: *UIData, allocator: std.mem.Allocator) void {
        self.texture_script_options.deinit();
        self.block_options.deinit();
        self.chunk_script_options.deinit();
        if (self.texture_rgba_data) |d| allocator.free(d);
        if (self.chunk_demo_data) |d| allocator.free(d);
    }
};

pub const UI = struct {
    gameFont: zgui.Font = undefined,
    codeFont: zgui.Font = undefined,
    data: *UIData = undefined,
};

pub const ElementsRendererConfig = struct {
    pub const AnimationKeyFrame = struct {
        scale: @Vector(4, gl.Float),
        rotation: @Vector(4, gl.Float),
        translation: @Vector(4, gl.Float),
    };
    vertexShader: [:0]const u8 = undefined,
    fragmentShader: [:0]const u8 = undefined,
    positions: [][3]gl.Float = undefined,
    indices: []u32 = undefined,
    texcoords: ?[][2]gl.Float = null,
    normals: ?[][3]gl.Float = null,
    transform: ?zm.Mat = null,
    ubo_binding_point: ?gl.Uint = null,
    demo_cube_texture: ?struct { usize, usize } = null,
    animation_binding_point: ?gl.Uint = null,
    keyframes: ?[]AnimationKeyFrame = null,
    is_instanced: bool = false,
    block_id: ?u8 = 0,
};

pub const Block = struct {
    id: u8,
    data: data.block,
};

pub const BlockInstance = struct {
    entity_id: blecs.ecs.entity_t = 0,
    transforms: std.ArrayList(zm.Mat) = undefined,
};

pub const Gfx = struct {
    ubos: std.AutoHashMap(gl.Uint, gl.Uint) = undefined,
    ssbos: std.AutoHashMap(gl.Uint, gl.Uint) = undefined,
    renderConfigs: std.AutoHashMap(blecs.ecs.entity_t, *ElementsRendererConfig) = undefined,
    blocks: std.AutoHashMap(u8, *Block) = undefined,
    game_blocks: std.AutoHashMap(u8, *BlockInstance) = undefined,
    settings_blocks: std.AutoHashMap(u8, *BlockInstance) = undefined,

    fn deinit(self: *Gfx, allocator: std.mem.Allocator) void {
        self.ubos.deinit();
        self.ssbos.deinit();
        var cfgs = self.renderConfigs.valueIterator();
        while (cfgs.next()) |rcfg| {
            allocator.destroy(rcfg);
        }
        var blocks = self.blocks.valueIterator();
        while (blocks.next()) |b| {
            allocator.free(b.*.data.texture);
            allocator.destroy(b.*);
        }
        self.blocks.deinit();
        var blocks_i = self.game_blocks.valueIterator();
        while (blocks_i.next()) |b| {
            b.*.transforms.deinit();
            allocator.destroy(b.*);
        }
        self.game_blocks.deinit();
        blocks_i = self.settings_blocks.valueIterator();
        while (blocks_i.next()) |b| {
            b.*.transforms.deinit();
            allocator.destroy(b.*);
        }
        self.settings_blocks.deinit();
        self.renderConfigs.deinit();
    }
};
pub const Game = struct {
    allocator: std.mem.Allocator = undefined,
    window: *glfw.Window = undefined,
    world: *blecs.ecs.world_t = undefined,
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
        try self.initGfx();
        try self.populateUIOptions();
    }

    pub fn deinit(self: *Game) void {
        self.script.deinit();
        self.db.deinit();
        self.ui.data.deinit(self.allocator);
        self.allocator.destroy(self.ui.data);
        self.gfx.deinit(self.allocator);
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
            .block_options = std.ArrayList(data.blockOption).init(self.allocator),
            .chunk_script_options = std.ArrayList(data.chunkScriptOption).init(self.allocator),
        };
    }

    pub fn initGfx(self: *Game) !void {
        self.gfx = Gfx{
            .ubos = std.AutoHashMap(gl.Uint, gl.Uint).init(self.allocator),
            .ssbos = std.AutoHashMap(gl.Uint, gl.Uint).init(self.allocator),
            .renderConfigs = std.AutoHashMap(blecs.ecs.entity_t, *ElementsRendererConfig).init(self.allocator),
            .game_blocks = std.AutoHashMap(u8, *BlockInstance).init(self.allocator),
            .settings_blocks = std.AutoHashMap(u8, *BlockInstance).init(self.allocator),
        };
        self.gfx.blocks = std.AutoHashMap(u8, *Block).init(self.allocator);
    }

    pub fn initScript(self: *Game) !void {
        self.script = try script.Script.init(self.allocator);
    }

    pub fn populateUIOptions(self: *Game) !void {
        try self.db.listBlocks(&self.ui.data.block_options);
        try self.db.listTextureScripts(&self.ui.data.texture_script_options);
        try self.db.listChunkScripts(&self.ui.data.chunk_script_options);

        var buf = [_]u8{0} ** script.maxLuaScriptSize;
        const defaultLuaScript = @embedFile("../script/lua/gen_wood_texture.lua");
        for (defaultLuaScript, 0..) |c, i| {
            buf[i] = c;
        }
        self.ui.data.texture_buf = buf;
        buf = [_]u8{0} ** script.maxLuaScriptSize;
        const defaultChunkScript = @embedFile("../script/lua/chunk_gen_complex.lua");
        for (defaultChunkScript, 0..) |c, i| {
            buf[i] = c;
        }
        self.ui.data.chunk_buf = buf;
    }
};
