const std = @import("std");
const glfw = @import("zglfw");
const zm = @import("zmath");
const zgui = @import("zgui");
const zmesh = @import("zmesh");
const blecs = @import("blecs/blecs.zig");
const data = @import("data/data.zig");
const gfx = @import("gfx/gfx.zig");
const script = @import("script/script.zig");
const chunk = @import("chunk.zig");
const mob = @import("mob.zig");
const thread = @import("thread/thread.zig");
const gltf = zmesh.io.zcgltf;

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
    third_person_camera: blecs.ecs.entity_t = 0,
    settings_camera: blecs.ecs.entity_t = 0,
    wall: blecs.ecs.entity_t = 0,
    ui: blecs.ecs.entity_t = 0,
    player: blecs.ecs.entity_t = 0,
    demo_player: blecs.ecs.entity_t = 0,
    block_highlight: blecs.ecs.entity_t = 0,
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
    chunkData: []u32 = undefined,
};

pub const UIData = struct {
    texture_script_options: std.ArrayList(data.scriptOption) = undefined,
    texture_loaded_script_id: i32 = 0,
    texture_buf: [script.maxLuaScriptSize]u8 = std.mem.zeroes([script.maxLuaScriptSize]u8),
    texture_name_buf: [script.maxLuaScriptNameSize]u8 = std.mem.zeroes([script.maxLuaScriptNameSize]u8),
    texture_rgba_data: ?[]u32 = null,
    texture_atlas_rgba_data: ?[]u32 = null,
    texture_atlas_block_index: [blecs.entities.block.MaxBlocks]usize = std.mem.zeroes([blecs.entities.block.MaxBlocks]usize),
    texture_atlas_num_blocks: usize = 0,
    block_options: std.ArrayList(data.blockOption) = undefined,
    block_create_name_buf: [data.maxBlockSizeName]u8 = std.mem.zeroes([data.maxBlockSizeName]u8),
    block_update_name_buf: [data.maxBlockSizeName]u8 = std.mem.zeroes([data.maxBlockSizeName]u8),
    block_loaded_block_id: u8 = 0,
    chunk_name_buf: [script.maxLuaScriptNameSize]u8 = std.mem.zeroes([script.maxLuaScriptNameSize]u8),
    chunk_buf: [script.maxLuaScriptSize]u8 = std.mem.zeroes([script.maxLuaScriptSize]u8),
    chunk_x_buf: [5]u8 = std.mem.zeroes([5]u8),
    chunk_y_buf: [5]u8 = std.mem.zeroes([5]u8),
    chunk_z_buf: [5]u8 = std.mem.zeroes([5]u8),
    chunk_script_options: std.ArrayList(data.chunkScriptOption) = undefined,
    chunk_loaded_script_id: i32 = 0,
    chunk_script_color: [3]f32 = std.mem.zeroes([3]f32),
    chunk_demo_data: ?[]u32 = null,
    world_name_buf: [max_world_name]u8 = std.mem.zeroes([max_world_name]u8),
    world_options: std.ArrayList(data.worldOption) = undefined,
    world_chunk_table_data: std.AutoHashMap(chunk.worldPosition, chunkConfig) = undefined,
    world_loaded_name: [max_world_name:0]u8 = std.mem.zeroes([max_world_name:0]u8),
    world_loaded_id: i32 = 0,
    world_chunk_y: i32 = 0,
    world_player_relocation: @Vector(4, f32) = .{ 32, 64, 32, 0 },
    world_current_chunk: @Vector(4, f32) = undefined,
    demo_cube_rotation: @Vector(4, f32) = zm.matToQuat(zm.rotationY(0 * std.math.pi)),
    demo_cube_translation: @Vector(4, f32) = @Vector(4, f32){ 0, 0, 0, 0 },
    demo_cube_pp_translation: @Vector(4, f32) = @Vector(4, f32){ -0.825, 0.650, 0, 0 },
    demo_cube_plane_1_tl: @Vector(4, f32) = @Vector(4, f32){ -0.926, 0.12, 0, 0 },
    demo_cube_plane_1_t2: @Vector(4, f32) = @Vector(4, f32){ -0.727, 0.090, 0, 0 },
    demo_cube_plane_1_t3: @Vector(4, f32) = @Vector(4, f32){ -0.926, -0.54, 0, 0 },
    demo_atlas_scale: @Vector(4, f32) = @Vector(4, f32){ 0.100, 1.940, 1, 0 },
    demo_atlas_translation: @Vector(4, f32) = @Vector(4, f32){ -0.976, -0.959, 0, 0 },
    demo_atlas_rotation: f32 = 0.5,
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
        if (self.texture_atlas_rgba_data) |d| allocator.free(d);
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
    vertexShader: ?[:0]const u8 = null,
    fragmentShader: ?[:0]const u8 = null,
    mesh_data: gfx.mesh.meshData = undefined,
    transform: ?zm.Mat = null,
    ubo_binding_point: ?u32 = null,
    demo_cube_texture: ?struct { usize, usize } = null,
    animation_binding_point: ?u32 = null,
    keyframes: ?[]AnimationKeyFrame = null,
    is_instanced: bool = false,
    block_id: ?u8 = 0,
    has_mob_texture: bool = false,
    has_block_texture_atlas: bool = false,
    is_multi_draw: bool = false,
    has_attr_translation: bool = false,
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

pub const Gfx = struct {
    ubos: std.AutoHashMap(u32, u32) = undefined,
    ssbos: std.AutoHashMap(u32, u32) = undefined,
    renderConfigs: std.AutoHashMap(blecs.ecs.entity_t, *ElementsRendererConfig) = undefined,
    blocks: std.AutoHashMap(u8, *Block) = undefined,
    game_blocks: std.AutoHashMap(u8, *BlockInstance) = undefined,
    settings_blocks: std.AutoHashMap(u8, *BlockInstance) = undefined,
    mob_data: std.AutoHashMap(i32, *mob.Mob) = undefined,
    animations_running: u32 = 0,
    settings_chunks: std.AutoHashMap(chunk.worldPosition, *chunk.Chunk) = undefined,
    game_chunks: std.AutoHashMap(chunk.worldPosition, *chunk.Chunk) = undefined,

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
        var mb_i = self.mob_data.valueIterator();
        while (mb_i.next()) |m| {
            m.*.deinit();
            allocator.destroy(m.*);
        }
        self.mob_data.deinit();
        var sc_i = self.settings_chunks.valueIterator();
        while (sc_i.next()) |ce| {
            ce.*.deinit();
            allocator.destroy(ce.*);
        }
        self.settings_chunks.deinit();
        var gc_i = self.game_chunks.valueIterator();
        while (gc_i.next()) |ce| {
            ce.*.deinit();
            allocator.destroy(ce.*);
        }
        self.game_chunks.deinit();
    }
};

pub const Game = struct {
    allocator: std.mem.Allocator = undefined,
    window: *glfw.Window = undefined,
    window_height: u32 = 0,
    window_width: u32 = 0,
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
        try self.initUIData();
        try self.initGfx();
        try self.initScript();
        try self.initDb();
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
        errdefer self.script.deinit();
        self.db = try data.Data.init(self.allocator);
        self.db.ensureSchema() catch |err| {
            std.log.err("Failed to ensure schema: {}\n", .{err});
            return err;
        };
        const had_world = self.db.ensureDefaultWorld() catch |err| {
            std.log.err("Failed to ensure default world: {}\n", .{err});
            return err;
        };
        if (had_world) return;
        try self.initInitialWorld();
        try self.initInitialPlayer(1);
    }

    pub fn initInitialWorld(self: *Game) !void {
        var dirt_texture_script = [_]u8{0} ** script.maxLuaScriptSize;
        const dtsb = @embedFile("script/lua/gen_dirt_texture.lua");
        for (dtsb, 0..) |c, i| {
            dirt_texture_script[i] = c;
        }
        const dirt_texture = try self.script.evalTextureFunc(dirt_texture_script);
        var grass_texture_script = [_]u8{0} ** script.maxLuaScriptSize;
        const gtsb = @embedFile("script/lua/gen_grass_texture.lua");
        for (gtsb, 0..) |c, i| {
            grass_texture_script[i] = c;
        }
        const grass_texture = try self.script.evalTextureFunc(grass_texture_script);
        if (dirt_texture == null or grass_texture == null) std.debug.panic("couldn't generate lua textures!\n", .{});
        try self.db.saveBlock("dirt", @ptrCast(dirt_texture.?));
        try self.db.saveBlock("grass", @ptrCast(grass_texture.?));
        const default_chunk_script: []const u8 = @embedFile("script/lua/chunk_gen_default.lua");
        try self.db.saveChunkScript("default", default_chunk_script, .{ 0, 1, 0 });
        const chunk_data = try self.script.evalChunkFunc(default_chunk_script);
        try self.db.saveChunkData(1, 0, 0, 0, 1, chunk_data);
        self.allocator.free(chunk_data);
        self.allocator.free(dirt_texture.?);
        self.allocator.free(grass_texture.?);
    }

    pub fn initInitialPlayer(self: *Game, world_id: i32) !void {
        const initial_pos: @Vector(4, f32) = .{ 32, 64, 32, 0 };
        const initial_rot: @Vector(4, f32) = .{ 0, 0, 0, 1 };
        const initial_angle: f32 = 0;
        try self.db.savePlayerPosition(world_id, initial_pos, initial_rot, initial_angle);
    }

    pub fn initUIData(self: *Game) !void {
        self.ui.data = try self.allocator.create(UIData);
        self.ui.data.* = .{
            .texture_script_options = std.ArrayList(data.scriptOption).init(self.allocator),
            .block_options = std.ArrayList(data.blockOption).init(self.allocator),
            .chunk_script_options = std.ArrayList(data.chunkScriptOption).init(self.allocator),
            .world_options = std.ArrayList(data.worldOption).init(self.allocator),
            .world_chunk_table_data = std.AutoHashMap(chunk.worldPosition, chunkConfig).init(self.allocator),
        };
    }

    pub fn initGfx(self: *Game) !void {
        self.gfx = .{
            .ubos = std.AutoHashMap(u32, u32).init(self.allocator),
            .ssbos = std.AutoHashMap(u32, u32).init(self.allocator),
            .renderConfigs = std.AutoHashMap(blecs.ecs.entity_t, *ElementsRendererConfig).init(self.allocator),
            .game_blocks = std.AutoHashMap(u8, *BlockInstance).init(self.allocator),
            .settings_blocks = std.AutoHashMap(u8, *BlockInstance).init(self.allocator),
            .settings_chunks = std.AutoHashMap(chunk.worldPosition, *chunk.Chunk).init(self.allocator),
            .game_chunks = std.AutoHashMap(chunk.worldPosition, *chunk.Chunk).init(self.allocator),
            .mob_data = std.AutoHashMap(i32, *mob.Mob).init(self.allocator),
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
        const defaultLuaScript = @embedFile("script/lua/gen_wood_texture.lua");
        for (defaultLuaScript, 0..) |c, i| {
            buf[i] = c;
        }
        self.ui.data.texture_buf = buf;
        buf = [_]u8{0} ** script.maxLuaScriptSize;
        const defaultChunkScript = @embedFile("script/lua/chunk_gen_complex.lua");
        for (defaultChunkScript, 0..) |c, i| {
            buf[i] = c;
        }
        self.ui.data.chunk_buf = buf;
    }
};
