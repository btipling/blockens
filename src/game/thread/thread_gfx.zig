count: u32 = 0,
allocator: std.mem.Allocator = undefined,
cmd_buffer: *GfxCommandBuffer,
exit: bool = false,
gl_ctx: *glfw.Window,

demo_sub_chunks_sorter: *chunk.sub_chunk.sorter = undefined,
game_sub_chunks_sorter: *chunk.sub_chunk.sorter = undefined,

const Ctx = @This();

threadlocal var ctx: *Ctx = undefined;
var gfx_thread: std.Thread = undefined;
var gfx_cmd_bufer: *GfxCommandBuffer = undefined;
pub var gfx_result_buffer: *GfxResultBuffer = undefined;

pub const GfxCommandBuffer = struct {
    pub const gfxCommandType = enum(u8) {
        count,
        exit,
        settings_sub_chunk,
        game_sub_chunk,
        settings_build_sub_chunk,
        game_build_sub_chunk,
        settings_clear_sub_chunk,
        game_clear_sub_chunk,
        game_cull_sub_chunk,
    };

    pub const cull_sub_chunk_data = struct {
        camera_position: @Vector(4, f32),
        view: zm.Mat,
        perspective: zm.Mat,
    };

    pub const gfxCommand = union(gfxCommandType) {
        count: void,
        exit: void,
        settings_sub_chunk: *chunk.sub_chunk,
        game_sub_chunk: *chunk.sub_chunk,
        settings_build_sub_chunk: void,
        game_build_sub_chunk: void,
        settings_clear_sub_chunk: void,
        game_clear_sub_chunk: void,
        game_cull_sub_chunk: cull_sub_chunk_data,
    };
    mutex: std.Thread.Mutex = .{},
    allocator: std.mem.Allocator,
    cmds: std.ArrayListUnmanaged(gfxCommand) = .{},

    pub fn init(allocator: std.mem.Allocator) *GfxCommandBuffer {
        const gcb = allocator.create(GfxCommandBuffer) catch @panic("OOM");
        gcb.* = .{
            .allocator = allocator,
        };
        return gcb;
    }

    pub fn deinit(self: *GfxCommandBuffer) void {
        self.cmds.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn send(self: *GfxCommandBuffer, cmd: gfxCommand) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.cmds.insert(self.allocator, 0, cmd) catch @panic("OOM");
    }

    pub fn read(self: *GfxCommandBuffer, handler: anytype) void {
        if (!self.mutex.tryLock()) return;
        defer self.mutex.unlock();
        while (true) {
            const cmd = self.cmds.popOrNull();
            if (cmd == null) break;
            @call(.auto, handler, .{cmd.?});
        }
    }
};

pub const GfxResultBuffer = struct {
    pub const gfxResultType = enum(u8) {
        settings_sub_chunk_draws,
        game_sub_chunk_draws,
    };

    pub const gfxResult = union(gfxResultType) {
        settings_sub_chunk_draws: gfx.GfxSubChunkDraws,
        game_sub_chunk_draws: gfx.GfxSubChunkDraws,
    };
    mutex: std.Thread.Mutex = .{},
    allocator: std.mem.Allocator,
    cmds: std.ArrayListUnmanaged(gfxResult) = .{},

    pub fn init(allocator: std.mem.Allocator) *GfxResultBuffer {
        const gcb = allocator.create(GfxResultBuffer) catch @panic("OOM");
        gcb.* = .{
            .allocator = allocator,
        };
        return gcb;
    }

    pub fn deinit(self: *GfxResultBuffer) void {
        self.cmds.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn send(self: *GfxResultBuffer, cmd: gfxResult) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.cmds.append(self.allocator, cmd) catch @panic("OOM");
    }

    pub fn read(self: *GfxResultBuffer, handler: anytype) void {
        if (!self.mutex.tryLock()) return;
        defer self.mutex.unlock();
        while (true) {
            const cmd = self.cmds.popOrNull();
            if (cmd == null) break;
            @call(.auto, handler, .{cmd.?});
        }
    }
};

const Args = struct {
    allocator: std.mem.Allocator,
    cmd_buffer: *GfxCommandBuffer,
    gl_ctx: *glfw.Window,
};

pub fn init(allocator: std.mem.Allocator, gl_ctx: *glfw.Window) void {
    const cfg: std.Thread.SpawnConfig = .{
        .stack_size = 16 * 1024 * 1024,
    };
    gfx_cmd_bufer = GfxCommandBuffer.init(allocator);
    gfx_result_buffer = GfxResultBuffer.init(allocator);
    const args: Args = .{
        .allocator = allocator,
        .cmd_buffer = gfx_cmd_bufer,
        .gl_ctx = gl_ctx,
    };
    gfx_thread = std.Thread.spawn(cfg, start, .{args}) catch |e| std.debug.panic(
        "gfx thread span werror{any}\n",
        .{e},
    );
    errdefer gfx_thread.join();
}

pub fn deinit() void {
    gfx_cmd_bufer.send(.exit);
    gfx_thread.join();
    gfx_cmd_bufer.deinit();
    gfx_result_buffer.deinit();
}

pub fn send(cmd: GfxCommandBuffer.gfxCommand) void {
    gfx_cmd_bufer.send(cmd);
}

fn start(args: Args) void {
    if (config.use_tracy) {
        const ztracy = @import("ztracy");
        ztracy.SetThreadName("GfxThread");
    }
    glfw.makeContextCurrent(args.gl_ctx);

    ctx = args.allocator.create(Ctx) catch @panic("OOM");
    var gbb: gfx.mesh_buffer_builder = .{
        .mesh_binding_point = gfx.constants.GameMeshDataBindingPoint,
        .draw_binding_point = gfx.constants.GameDrawBindingPoint,
        .with_allocation = true,
    };
    var sbb: gfx.mesh_buffer_builder = .{
        .mesh_binding_point = gfx.constants.SettingsMeshDataBindingPoint,
        .draw_binding_point = gfx.constants.SettingsDrawBindingPoint,
    };
    gbb.init();
    sbb.init();
    ctx.* = .{
        .allocator = args.allocator,
        .cmd_buffer = args.cmd_buffer,
        .game_sub_chunks_sorter = chunk.sub_chunk.sorter.init(args.allocator, gbb),
        .demo_sub_chunks_sorter = chunk.sub_chunk.sorter.init(args.allocator, sbb),
        .gl_ctx = args.gl_ctx,
    };
    ctx.run();
}

fn handle(cmd: GfxCommandBuffer.gfxCommand) void {
    switch (cmd) {
        .count => {
            ctx.count += 1;
        },
        .exit => {
            ctx.exit = true;
        },
        .settings_sub_chunk => |sc| {
            ctx.demo_sub_chunks_sorter.addSubChunk(sc);
        },
        .game_sub_chunk => |sc| {
            ctx.game_sub_chunks_sorter.addSubChunk(sc);
        },
        .settings_build_sub_chunk => {
            ctx.demo_sub_chunks_sorter.buildMeshData();
            ctx.demo_sub_chunks_sorter.sort(.{ 0, 0, 0, 0 });
            gfx_result_buffer.send(.{ .settings_sub_chunk_draws = .{
                .num_indices = ctx.demo_sub_chunks_sorter.num_indices,
                .first = ctx.demo_sub_chunks_sorter.opaque_draw_first.toOwnedSlice(ctx.allocator) catch @panic("OOM"),
                .count = ctx.demo_sub_chunks_sorter.opaque_draw_count.toOwnedSlice(ctx.allocator) catch @panic("OOM"),
            } });
        },
        .game_build_sub_chunk => {
            ctx.game_sub_chunks_sorter.buildMeshData();
            ctx.game_sub_chunks_sorter.sort(.{ 0, 0, 0, 0 });
            gfx_result_buffer.send(.{ .game_sub_chunk_draws = .{
                .num_indices = ctx.game_sub_chunks_sorter.num_indices,
                .first = ctx.game_sub_chunks_sorter.opaque_draw_first.toOwnedSlice(ctx.allocator) catch @panic("OOM"),
                .count = ctx.game_sub_chunks_sorter.opaque_draw_count.toOwnedSlice(ctx.allocator) catch @panic("OOM"),
            } });
        },
        .settings_clear_sub_chunk => ctx.demo_sub_chunks_sorter.clear(),
        .game_clear_sub_chunk => ctx.game_sub_chunks_sorter.clear(),
        .game_cull_sub_chunk => |cd| {
            _ = ctx.game_sub_chunks_sorter.setCamera(cd.camera_position, cd.view, cd.perspective);
            ctx.game_sub_chunks_sorter.cullFrustum();
            ctx.game_sub_chunks_sorter.sort(.{ 0, 0, 0, 0 });
            gfx_result_buffer.send(.{ .game_sub_chunk_draws = .{
                .num_indices = ctx.game_sub_chunks_sorter.num_indices,
                .first = ctx.game_sub_chunks_sorter.opaque_draw_first.toOwnedSlice(ctx.allocator) catch @panic("OOM"),
                .count = ctx.game_sub_chunks_sorter.opaque_draw_count.toOwnedSlice(ctx.allocator) catch @panic("OOM"),
            } });
        },
    }
    return;
}

fn run(self: *Ctx) void {
    if (config.use_tracy) {
        const ztracy = @import("ztracy");
        const tracy_zone = ztracy.ZoneNC(@src(), "GfxThreadRun", 0x0F_CF_82_f0);
        defer tracy_zone.End();
        self._run();
        return;
    }
    self._run();
}

fn _run(self: *Ctx) void {
    errdefer self.end();
    while (!self.exit) {
        glfw.makeContextCurrent(ctx.gl_ctx);
        std.time.sleep(std.time.ns_per_ms * 1);
        self.cmd_buffer.read(handle);
        std.Thread.yield() catch {};
    }
    ctx.end();
}

fn end(self: *Ctx) void {
    std.debug.print("exiting gfx thread, final count: {d}", .{self.count});
    self.demo_sub_chunks_sorter.deinit();
    self.game_sub_chunks_sorter.deinit();
    self.allocator.destroy(self);
}

const std = @import("std");
const zm = @import("zmath");
const glfw = @import("zglfw");
const config = @import("config");
const zopengl = @import("zopengl");
const gfx = @import("../gfx/gfx.zig");
const block = @import("../block/block.zig");
const chunk = block.chunk;
