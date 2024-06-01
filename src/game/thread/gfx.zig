count: u32 = 0,
allocator: std.mem.Allocator = undefined,
cmd_buffer: *GfxCommandBuffer,
exit: bool = false,

const Ctx = @This();

threadlocal var ctx: *Ctx = undefined;
var gfx_thread: std.Thread = undefined;
var gfx_cmd_bufer: *GfxCommandBuffer = undefined;

pub const GfxCommandBuffer = struct {
    pub const gfxCommand = enum(u8) {
        count,
        exit,
    };

    pub const gfxCommandData = union(gfxCommand) {
        count: void,
        exit: void,
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
        self.cmds.append(self.allocator, cmd) catch @panic("OOM");
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

const Args = struct {
    allocator: std.mem.Allocator,
    cmd_buffer: *GfxCommandBuffer,
};

pub fn init(allocator: std.mem.Allocator) void {
    const cfg: std.Thread.SpawnConfig = .{
        .stack_size = 16 * 1024 * 1024,
    };
    gfx_cmd_bufer = GfxCommandBuffer.init(allocator);
    const args: Args = .{
        .allocator = allocator,
        .cmd_buffer = gfx_cmd_bufer,
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
}

pub fn send(cmd: GfxCommandBuffer.gfxCommand) void {
    gfx_cmd_bufer.send(cmd);
}

fn start(args: Args) void {
    ctx = args.allocator.create(Ctx) catch @panic("OOM");
    ctx.* = .{
        .allocator = args.allocator,
        .cmd_buffer = args.cmd_buffer,
    };
    ctx.run();
}

fn handle(cmd: GfxCommandBuffer.gfxCommand) void {
    switch (cmd) {
        .count => {
            ctx.count += 1;
            std.debug.print("count is: {d}\n", .{ctx.count});
        },
        .exit => {
            ctx.exit = true;
        },
    }
    return;
}

fn run(self: *Ctx) void {
    while (!self.exit) {
        std.time.sleep(std.time.ns_per_ms * 100);
        self.cmd_buffer.read(handle);
        std.Thread.yield() catch {};
    }
    ctx.end();
}

fn end(self: *Ctx) void {
    std.debug.print("exiting gfx thread, final count: {d}", .{self.count});
    self.allocator.destroy(self);
}

const std = @import("std");
