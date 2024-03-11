const std = @import("std");
const glfw = @import("zglfw");
const blecs = @import("../blecs/blecs.zig");
const zm = @import("zmath");
const zgui = @import("zgui");
const zmesh = @import("zmesh");
const data = @import("../data/data.zig");
const script = @import("../script/script.zig");
const chunk = @import("../chunk.zig");
const thread = @import("../thread/thread.zig");
const gltf = zmesh.io.zcgltf;
pub const position = @import("position.zig");

pub const max_world_name = 20;

pub const Entities = struct {
    screen: blecs.ecs.entity_t = 0,
    clock: blecs.ecs.entity_t = 0,
    gfx: blecs.ecs.entity_t = 0,
    sky: blecs.ecs.entity_t = 0,
    floor: blecs.ecs.entity_t = 0,
    crosshair: blecs.ecs.entity_t = 0,
    menu: blecs.ecs.entity_t = 0,
    sky_camera: blecs.ecs.entity_t = 0,
    settings_camera: blecs.ecs.entity_t = 0,
    wall: blecs.ecs.entity_t = 0,
    ui: blecs.ecs.entity_t = 0,
    player: blecs.ecs.entity_t = 0,
    demo_player: blecs.ecs.entity_t = 0,
};

pub const Cursor = struct {
    last_x: f32 = 0,
    last_y: f32 = 0,
};

pub const Input = struct {
    last_key: i64 = 0,
    cursor: ?Cursor = null,
    lastframe: f32 = 0,
    delta_time: f32 = 0,
};

pub const chunkConfig = struct {
    id: i32 = 0, // from sqlite
    scriptId: i32,
    chunkData: []i32 = undefined,
};

pub const UIData = struct {
    texture_script_options: std.ArrayList(data.scriptOption) = undefined,
    texture_loaded_script_id: i32 = 0,
    texture_buf: [script.maxLuaScriptSize]u8 = [_]u8{0} ** script.maxLuaScriptSize,
    texture_name_buf: [script.maxLuaScriptNameSize]u8 = [_]u8{0} ** script.maxLuaScriptNameSize,
    texture_rgba_data: ?[]u32 = null,
    block_options: std.ArrayList(data.blockOption) = undefined,
    block_create_name_buf: [data.maxBlockSizeName]u8 = [_]u8{0} ** data.maxBlockSizeName,
    block_update_name_buf: [data.maxBlockSizeName]u8 = [_]u8{0} ** data.maxBlockSizeName,
    block_loaded_block_id: u8 = 0,
    chunk_name_buf: [script.maxLuaScriptNameSize]u8 = [_]u8{0} ** script.maxLuaScriptNameSize,
    chunk_buf: [script.maxLuaScriptSize]u8 = [_]u8{0} ** script.maxLuaScriptSize,
    chunk_x_buf: [5]u8 = [_]u8{0} ** 5,
    chunk_y_buf: [5]u8 = [_]u8{0} ** 5,
    chunk_z_buf: [5]u8 = [_]u8{0} ** 5,
    chunk_script_options: std.ArrayList(data.chunkScriptOption) = undefined,
    chunk_loaded_script_id: i32 = 0,
    chunk_script_color: [3]f32 = [_]f32{0} ** 3,
    chunk_demo_data: ?[]i32 = null,
    world_load_disabled: bool = false,
    world_name_buf: [max_world_name]u8 = [_]u8{0} ** max_world_name,
    world_options: std.ArrayList(data.worldOption) = undefined,
    world_chunk_table_data: std.AutoHashMap(position.worldPosition, chunkConfig) = undefined,
    world_loaded_id: i32 = 0,
    world_chunk_y: i32 = 0,
    world_current_chunk: @Vector(4, f32) = undefined,
    demo_cube_rotation: @Vector(4, f32) = zm.matToQuat(zm.rotationY(0 * std.math.pi)),
    demo_cube_translation: @Vector(4, f32) = @Vector(4, f32){ 0, 0, 0, 0 },
    demo_cube_pp_translation: @Vector(4, f32) = @Vector(4, f32){ -0.825, 0.650, 0, 0 },
    demo_cube_plane_1_tl: @Vector(4, f32) = @Vector(4, f32){ -0.926, 0.12, 0, 0 },
    demo_cube_plane_1_t2: @Vector(4, f32) = @Vector(4, f32){ -0.727, 0.090, 0, 0 },
    demo_cube_plane_1_t3: @Vector(4, f32) = @Vector(4, f32){ -0.926, -0.54, 0, 0 },
    demo_chunk_rotation_x: f32 = 0,
    demo_chunk_rotation_y: f32 = 0.341,
    demo_chunk_rotation_z: f32 = 0.083,
    demo_chunk_scale: f32 = 0.042,
    demo_chunk_translation: @Vector(4, f32) = @Vector(4, f32){
        2.55,
        0.660,
        -0.264,
        0,
    },
    demo_chunk_pp_translation: @Vector(4, f32) = @Vector(4, f32){
        -0.650,
        0.100,
        0,
        0,
    },
    demo_character_rotation_x: f32 = 0.500,
    demo_character_rotation_y: f32 = 0.536,
    demo_character_rotation_z: f32 = 0.501,
    demo_character_scale: f32 = 0.235,
    demo_character_translation: @Vector(4, f32) = @Vector(4, f32){
        -7.393,
        -0.293,
        -0.060,
        0,
    },
    demo_character_pp_translation: @Vector(4, f32) = @Vector(4, f32){
        -0.259,
        0.217,
        0,
        0,
    },

    fn deinit(self: *UIData, allocator: std.mem.Allocator) void {
        self.texture_script_options.deinit();
        self.block_options.deinit();
        self.chunk_script_options.deinit();
        self.world_options.deinit();
        var td = self.world_chunk_table_data.valueIterator();
        while (td.next()) |cc| {
            allocator.free(cc.*.chunkData);
        }
        self.world_chunk_table_data.deinit();
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
        frame: f32,
        scale: @Vector(4, f32),
        rotation: @Vector(4, f32),
        translation: @Vector(4, f32),
    };
    pub const MobRef = struct {
        mob_id: i32,
        mesh_id: u32,
    };
    vertexShader: [:0]const u8 = undefined,
    fragmentShader: [:0]const u8 = undefined,
    positions: [][3]f32 = undefined,
    indices: []u32 = undefined,
    texcoords: ?[][2]f32 = null,
    normals: ?[][3]f32 = null,
    transform: ?zm.Mat = null,
    ubo_binding_point: ?u32 = null,
    demo_cube_texture: ?struct { usize, usize } = null,
    animation_binding_point: ?u32 = null,
    keyframes: ?[]AnimationKeyFrame = null,
    is_instanced: bool = false,
    block_id: ?u8 = 0,
    has_mob_texture: bool = false,
    mob: ?MobRef = null,
};

pub const Block = struct {
    id: u8,
    data: data.block,
};

pub const BlockInstance = struct {
    entity_id: blecs.ecs.entity_t = 0,
    vbo: u32 = 0,
    transforms: std.ArrayList(zm.Mat) = undefined,
};

pub const MobCamera = struct {
    // TODO: add camera name and deinit
    aspectRatio: f32 = 1,
    yfov: f32 = 1,
    znear: f32 = 1,
    zfar: f32 = 500,
};

pub const MobAnimation = struct {
    frame: f32 = 0,
    scale: ?@Vector(4, f32) = null,
    rotation: ?@Vector(4, f32) = null,
    translation: ?@Vector(4, f32) = null,
};

pub const MobMesh = struct {
    id: usize = 0,
    parent: ?usize = null,
    transform: ?zm.Mat = null,
    indices: std.ArrayList(u32),
    positions: std.ArrayList([3]f32),
    normals: std.ArrayList([3]f32),
    textcoords: std.ArrayList([2]f32),
    tangents: std.ArrayList([4]f32),
    animations: ?std.ArrayList(MobAnimation) = null,
    scale: ?@Vector(4, f32) = null,
    rotation: ?@Vector(4, f32) = null,
    translation: ?@Vector(4, f32) = null,
    color: @Vector(4, f32) = .{ 1.0, 0.0, 1.0, 1.0 },
    texture: ?[]u8 = null,

    pub fn init(
        allocator: std.mem.Allocator,
        id: usize,
        parent: ?usize,
        color: @Vector(4, f32),
        texture: ?[]u8,
        animations: ?std.ArrayList(MobAnimation),
    ) *MobMesh {
        var m: *MobMesh = allocator.create(MobMesh) catch unreachable;
        _ = &m;
        m.* = .{
            .indices = std.ArrayList(u32).init(allocator),
            .positions = std.ArrayList([3]f32).init(allocator),
            .normals = std.ArrayList([3]f32).init(allocator),
            .textcoords = std.ArrayList([2]f32).init(allocator),
            .tangents = std.ArrayList([4]f32).init(allocator),
            .id = id,
            .parent = parent,
            .color = color,
            .texture = texture,
            .animations = animations,
        };
        return m;
    }

    fn deinit(self: MobMesh, allocator: std.mem.Allocator) void {
        self.indices.deinit();
        self.positions.deinit();
        self.normals.deinit();
        self.textcoords.deinit();
        self.tangents.deinit();
        if (self.animations) |a| a.deinit();
        if (self.texture) |t| allocator.free(t);
    }
};

pub const Mob = struct {
    id: i32,
    meshes: std.ArrayList(*MobMesh) = undefined,
    cameras: ?std.ArrayList(MobCamera) = null,
    pub fn init(allocator: std.mem.Allocator, id: i32, num_meshes: usize) *Mob {
        var m: *Mob = allocator.create(Mob) catch unreachable;
        _ = &m;
        var meshes = std.ArrayList(*MobMesh).initCapacity(
            allocator,
            num_meshes,
        ) catch unreachable;
        meshes.expandToCapacity();
        m.* = .{
            .id = id,
            .meshes = meshes,
        };
        return m;
    }

    pub fn deinit(self: *Mob, allocator: std.mem.Allocator) void {
        for (self.meshes.items) |m| {
            m.deinit(allocator);
            allocator.destroy(m);
        }
        self.meshes.deinit();
    }
};

pub const Gfx = struct {
    ubos: std.AutoHashMap(u32, u32) = undefined,
    ssbos: std.AutoHashMap(u32, u32) = undefined,
    renderConfigs: std.AutoHashMap(blecs.ecs.entity_t, *ElementsRendererConfig) = undefined,
    blocks: std.AutoHashMap(u8, *Block) = undefined,
    game_blocks: std.AutoHashMap(u8, *BlockInstance) = undefined,
    settings_blocks: std.AutoHashMap(u8, *BlockInstance) = undefined,
    mesh_data: std.AutoHashMap(blecs.ecs.entity_t, *chunk.Chunk) = undefined,
    mob_data: std.AutoHashMap(i32, *Mob) = undefined,
    animations_running: u32 = 0,

    fn deinit(self: *Gfx, allocator: std.mem.Allocator) void {
        self.ubos.deinit();
        self.ssbos.deinit();
        var cfgs = self.renderConfigs.valueIterator();
        while (cfgs.next()) |rcfg| {
            allocator.destroy(rcfg);
        }
        self.renderConfigs.deinit();
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
        var md_i = self.mesh_data.valueIterator();
        while (md_i.next()) |c| {
            c.*.deinit();
            allocator.destroy(c.*);
        }
        self.mesh_data.deinit();
        var mb_i = self.mob_data.valueIterator();
        while (mb_i.next()) |m| {
            m.*.deinit(allocator);
            allocator.destroy(m.*);
        }
        self.mob_data.deinit();
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
    jobs: thread.jobs.Jobs = .{},
    quit: bool = false,

    pub fn initInternals(self: *Game) !void {
        try self.initDb();
        try self.initScript();
        try self.initUIData();
        try self.initGfx();
        try self.populateUIOptions();
        self.jobs = thread.jobs.Jobs.init();
        self.jobs.start();
        try thread.handler.init();
        try thread.buffer.init(self.allocator);
    }

    pub fn deinit(self: *Game) void {
        self.jobs.deinit();
        self.script.deinit();
        self.db.deinit();
        self.ui.data.deinit(self.allocator);
        self.allocator.destroy(self.ui.data);
        self.gfx.deinit(self.allocator);
        thread.buffer.deinit();
        thread.handler.deinit();
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
        self.ui.data.* = .{
            .texture_script_options = std.ArrayList(data.scriptOption).init(self.allocator),
            .block_options = std.ArrayList(data.blockOption).init(self.allocator),
            .chunk_script_options = std.ArrayList(data.chunkScriptOption).init(self.allocator),
            .world_options = std.ArrayList(data.worldOption).init(self.allocator),
            .world_chunk_table_data = std.AutoHashMap(position.worldPosition, chunkConfig).init(self.allocator),
        };
    }

    pub fn initGfx(self: *Game) !void {
        self.gfx = .{
            .ubos = std.AutoHashMap(u32, u32).init(self.allocator),
            .ssbos = std.AutoHashMap(u32, u32).init(self.allocator),
            .renderConfigs = std.AutoHashMap(blecs.ecs.entity_t, *ElementsRendererConfig).init(self.allocator),
            .game_blocks = std.AutoHashMap(u8, *BlockInstance).init(self.allocator),
            .settings_blocks = std.AutoHashMap(u8, *BlockInstance).init(self.allocator),
            .mesh_data = std.AutoHashMap(blecs.ecs.entity_t, *chunk.Chunk).init(self.allocator),
            .mob_data = std.AutoHashMap(i32, *Mob).init(self.allocator),
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
        try self.db.listWorlds(&self.ui.data.world_options);

        var world_data: data.world = undefined;
        try self.db.loadWorld(1, &world_data);
        var world_name_buf = [_]u8{0} ** max_world_name;
        for (world_data.name, 0..) |c, i| {
            if (i >= max_world_name) {
                break;
            }
            world_name_buf[i] = c;
        }
        self.ui.data.world_name_buf = world_name_buf;
        self.ui.data.world_loaded_id = 1;

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
