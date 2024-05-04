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

        self.jobs.start();

        try thread.handler.init();
        errdefer thread.handler.deinit();
        try thread.buffer.init(self.allocator);
        errdefer thread.buffer.deinit();

        _ = self.jobs.start_up();
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

    pub fn initScript(self: *Game) !void {
        self.script = try script.Script.init(self.allocator);
    }

    pub fn populateUIOptions(self: *Game) !void {
        std.debug.print("populate ui options\n", .{});
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
