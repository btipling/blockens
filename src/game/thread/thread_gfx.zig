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

    pub fn trySend(self: *GfxCommandBuffer, cmd: gfxCommand) void {
        if (!self.mutex.tryLock()) return;
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
        new_ssbo,
        game_sub_chunks_ready,
    };

    pub const gfxResult = union(gfxResultType) {
        settings_sub_chunk_draws: gfx.GfxSubChunkDraws,
        game_sub_chunk_draws: gfx.GfxSubChunkDraws,
        new_ssbo: struct { ssbo: u32, binding_point: u32 },
        game_sub_chunks_ready: void,
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
        for (self.cmds.items) |cmd| {
            switch (cmd) {
                gfxResult.game_sub_chunk_draws => |d| d.deinit(self.allocator),
                gfxResult.settings_sub_chunk_draws => |d| d.deinit(self.allocator),
                else => {},
            }
        }
        self.cmds.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn send(self: *GfxResultBuffer, cmd: gfxResult) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.cmds.append(self.allocator, cmd) catch @panic("OOM");
    }

    pub fn read(self: *GfxResultBuffer, handler: anytype) void {
        if (config.use_tracy) ztracy.Message("GfxResultBuffer: read");
        if (!self.mutex.tryLock()) {
            if (config.use_tracy) ztracy.Message("GfxResultBuffer: tried lock");
            return;
        }
        if (config.use_tracy) ztracy.Message("GfxResultBuffer: reading");
        defer self.mutex.unlock();
        while (true) {
            const cmd = self.cmds.popOrNull();
            if (cmd == null) break;
            @call(.auto, handler, .{cmd.?});
        }
        if (config.use_tracy) ztracy.Message("GfxResultBuffer: done reading");
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
pub fn trySend(cmd: GfxCommandBuffer.gfxCommand) void {
    gfx_cmd_bufer.trySend(cmd);
}

fn start(args: Args) void {
    if (config.use_tracy) {
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
    gfx_result_buffer.send(.{ .new_ssbo = .{
        .ssbo = gbb.buffer_ssbo,
        .binding_point = gbb.mesh_binding_point,
    } });
    gfx_result_buffer.send(.{ .new_ssbo = .{
        .ssbo = gbb.draw_ssbo,
        .binding_point = gbb.draw_binding_point,
    } });
    gfx_result_buffer.send(.{ .new_ssbo = .{
        .ssbo = sbb.buffer_ssbo,
        .binding_point = sbb.mesh_binding_point,
    } });
    gfx_result_buffer.send(.{ .new_ssbo = .{
        .ssbo = sbb.draw_ssbo,
        .binding_point = sbb.draw_binding_point,
    } });
    ctx.run();
}

fn handle(cmd: GfxCommandBuffer.gfxCommand) void {
    switch (cmd) {
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
            gfx_result_buffer.send(.{ .game_sub_chunks_ready = {} });
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
    errdefer self.end();
    while (!self.exit) {
        if (config.use_tracy) {
            const tracy_zone = ztracy.ZoneNC(@src(), "GfxThreadRun", 0x0F_CF_82_f0);
            defer tracy_zone.End();
            self.loop();
            continue;
        }
        self.loop();
    }
    ctx.end();
}

fn loop(self: *Ctx) void {
    glfw.makeContextCurrent(ctx.gl_ctx);
    self.cmd_buffer.read(handle);
}

fn end(self: *Ctx) void {
    std.debug.print("exiting gfx thread", .{});
    self.demo_sub_chunks_sorter.deinit();
    self.game_sub_chunks_sorter.deinit();
    self.allocator.destroy(self);
}

const std = @import("std");
const zm = @import("zmath");
const glfw = @import("zglfw");
const ztracy = @import("ztracy");
const config = @import("config");
const zopengl = @import("zopengl");
const gfx = @import("../gfx/gfx.zig");
const block = @import("../block/block.zig");
const chunk = block.chunk;
