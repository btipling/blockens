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

pub const Game = struct {
    allocator: std.mem.Allocator = undefined,
    window: *glfw.Window = undefined,
    world: *blecs.ecs.world_t = undefined,
    db: data.Data = undefined,
    script: script.Script = undefined,
    entities: Entities = .{},
    input: Input = .{},
    ui: *ui = undefined,
    gfx: *gfx.Gfx = undefined,
    blocks: *block.Blocks = undefined,
    jobs: thread.jobs.Jobs = .{},
    quit: bool = false,

    pub fn initInternals(self: *Game) !void {
        self.gfx = gfx.init(self.allocator);
        errdefer gfx.deinit(self.allocator);
        self.blocks = block.init(self.allocator);
        errdefer block.deinit(self.allocator);
        self.jobs = thread.jobs.Jobs.init();
        errdefer self.jobs.deinit();
        try self.initScript();
        errdefer self.deinit();

        try self.setupDB();
        try self.populateUIOptions();
        self.jobs.start();

        try thread.handler.init();
        errdefer thread.handler.deinit();
        try thread.buffer.init(self.allocator);
        errdefer thread.buffer.deinit();
    }

    pub fn deinit(self: *Game) void {
        self.jobs.deinit();
        self.script.deinit();
        self.db.deinit();
        ui.deinit(self.allocator);
        gfx.deinit(self.allocator);
        block.deinit(self.allocator);
        thread.buffer.deinit();
        thread.handler.deinit();
    }

    pub fn setupDB(self: *Game) !void {
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
        defer self.allocator.free(dirt_texture.?);
        var grass_texture_script = [_]u8{0} ** script.maxLuaScriptSize;
        const gtsb = @embedFile("script/lua/gen_grass_texture.lua");
        for (gtsb, 0..) |c, i| {
            grass_texture_script[i] = c;
        }
        const grass_texture = try self.script.evalTextureFunc(grass_texture_script);
        defer self.allocator.free(grass_texture.?);
        if (dirt_texture == null or grass_texture == null) std.debug.panic("couldn't generate lua textures!\n", .{});
        try self.db.saveBlock("dirt", @ptrCast(dirt_texture.?), false, 0);
        try self.db.saveBlock("grass", @ptrCast(grass_texture.?), false, 0);
        const default_chunk_script: []const u8 = @embedFile("script/lua/chunk_gen_default.lua");
        try self.db.saveChunkScript("default", default_chunk_script, .{ 0, 1, 0 });
        {
            const top_chunk: []u64 = try self.allocator.alloc(u64, chunk.chunkSize);
            defer self.allocator.free(top_chunk);
            const bottom_chunk: []u64 = try self.allocator.alloc(u64, chunk.chunkSize);
            defer self.allocator.free(bottom_chunk);

            @memset(top_chunk, 0);
            @memset(bottom_chunk, 0);

            try self.db.saveChunkMetadata(1, 0, 1, 0, 1);
            try self.db.saveChunkMetadata(1, 0, 0, 0, 1);
            data.chunk_file.saveChunkData(self.allocator, 1, 0, 0, top_chunk, bottom_chunk);
        }
    }

    pub fn initInitialPlayer(self: *Game, world_id: i32) !void {
        const initial_pos: @Vector(4, f32) = .{ 32, 64, 32, 0 };
        const initial_rot: @Vector(4, f32) = .{ 0, 0, 0, 1 };
        const initial_angle: f32 = 0;
        try self.db.savePlayerPosition(world_id, initial_pos, initial_rot, initial_angle);
    }

    pub fn initScript(self: *Game) !void {
        self.script = try script.Script.init(self.allocator);
    }

    pub fn populateUIOptions(self: *Game) !void {
        try self.db.listBlocks(&self.ui.block_options);
        try self.db.listTextureScripts(&self.ui.texture_script_options);
        try self.db.listChunkScripts(&self.ui.chunk_script_options);
        try self.db.listWorlds(&self.ui.world_options);

        var world_data: data.world = undefined;
        try self.db.loadWorld(1, &world_data);
        var world_name_buf = [_]u8{0} ** ui.max_world_name;
        for (world_data.name, 0..) |c, i| {
            if (i >= ui.max_world_name) {
                break;
            }
            world_name_buf[i] = c;
        }
        self.ui.world_name_buf = world_name_buf;
        self.ui.world_loaded_id = 1;

        var buf = [_]u8{0} ** script.maxLuaScriptSize;
        const defaultLuaScript = @embedFile("script/lua/gen_grass_texture.lua");
        for (defaultLuaScript, 0..) |c, i| {
            buf[i] = c;
        }
        self.ui.texture_buf = buf;
        buf = [_]u8{0} ** script.maxLuaScriptSize;
        const defaultChunkScript = @embedFile("script/lua/chunk_gen_default.lua");
        for (defaultChunkScript, 0..) |c, i| {
            buf[i] = c;
        }
        self.ui.chunk_buf = buf;
    }
};

const std = @import("std");
const glfw = @import("zglfw");
const blecs = @import("blecs/blecs.zig");
const data = @import("data/data.zig");
const gfx = @import("gfx/gfx.zig");
const script = @import("script/script.zig");
const mob = @import("mob.zig");
const ui = @import("ui.zig");
const thread = @import("thread/thread.zig");
const block = @import("block/block.zig");
const chunk = block.chunk;
