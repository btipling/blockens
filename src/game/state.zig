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
    ts_allocator: std.mem.Allocator = undefined,
    ta: std.heap.ThreadSafeAllocator = undefined,
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
        self.ta = .{
            .child_allocator = self.allocator,
        };
        self.ts_allocator = self.ta.allocator();
        self.gfx = gfx.init(self.allocator);
        errdefer gfx.deinit();
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
        ui.deinit();
        gfx.deinit();
        block.deinit(self.allocator);
        thread.buffer.deinit();
        thread.handler.deinit();
    }

    pub fn initScript(self: *Game) !void {
        self.script = try script.Script.init(self.allocator);
    }

    pub fn populateUIOptions(self: *Game) !void {
        std.debug.print("populate ui options\n", .{});
        try self.db.listBlocks(self.ui.allocator, &self.ui.block_options);
        try self.db.listTextureScripts(self.ui.allocator, &self.ui.texture_script_options);
        try self.db.listChunkScripts(self.ui.allocator, &self.ui.chunk_script_options);
        try self.db.listWorlds(self.ui.allocator, &self.ui.world_options);
        try self.db.listTerrainGenScripts(self.ui.allocator, &self.ui.terrain_gen_script_options);

        var buf = [_]u8{0} ** script.maxLuaScriptSize;
        const defaultLuaScript = @embedFile("script/lua/gen_grass_texture.lua");
        for (defaultLuaScript, 0..) |c, i| {
            buf[i] = c;
        }
        self.ui.texture_buf = buf;
        buf = [_]u8{0} ** script.maxLuaScriptSize;
        const defaultcolorScript = @embedFile("script/lua/chunk_gen_default.lua");
        for (defaultcolorScript, 0..) |c, i| {
            buf[i] = c;
        }
        self.ui.chunk_buf = buf;
        if (self.ui.world_options.items.len > 0) {
            self.ui.world_loaded_id = self.ui.world_options.items[0].id;
            @memcpy(self.ui.world_loaded_name[0..20], self.ui.world_options.items[0].name[0..20]);
        }
    }
};

const std = @import("std");
const glfw = @import("zglfw");
const blecs = @import("blecs/blecs.zig");
const data = @import("data/data.zig");
const gfx = @import("gfx/gfx.zig");
const script = @import("script/script.zig");
const mob = @import("mob.zig");
const ui = @import("ui/ui.zig");
const thread = @import("thread/thread.zig");
const block = @import("block/block.zig");
const chunk = block.chunk;
