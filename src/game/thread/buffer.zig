const std = @import("std");
const chunk = @import("../chunk.zig");
const state = @import("../state.zig");
const blecs = @import("../blecs/blecs.zig");

var id: u64 = 0;

var ta: std.heap.ThreadSafeAllocator = undefined;
var buffer: *Buffer = undefined;

pub const BufferErr = error{
    Invalid,
};

pub const buffer_message_type = enum {
    chunk_gen,
    chunk_mesh,
    chunk_copy,
    lighting,
};

pub const buffer_data = union(buffer_message_type) {
    chunk_gen: chunk_gen_data,
    chunk_mesh: chunk_mesh_data,
    chunk_copy: chunk_copy_data,
    lighting: lightings_data,
};

pub const buffer_message = packed struct {
    id: u64 = 0,
    ts: i64 = 0,
    type: buffer_message_type,
    flags: u16 = 0,
    data: u16 = 0,
};

pub const chunk_gen_data = struct {
    wp: ?chunk.worldPosition = null,
    chunk_data: []u32,
};

pub const chunk_mesh_data = struct {
    world: ?*blecs.ecs.world_t = null,
    entity: ?blecs.ecs.entity_t = null,
    empty: bool = false,
    chunk: *chunk.Chunk,
};

pub const chunk_copy_data = struct {
    chunk: *chunk.Chunk,
};

pub const lightings_data = struct {
    world_id: i32,
    x: i32,
    z: i32,
};

const Buffer = struct {
    ta: std.heap.ThreadSafeAllocator,
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,
    messages: std.ArrayList(buffer_message),
    data: std.AutoHashMap(buffer_message, buffer_data),
};

pub fn init(allocator: std.mem.Allocator) !void {
    ta = .{
        .child_allocator = allocator,
    };
    var a = ta.allocator();
    buffer = try a.create(Buffer);
    buffer.* = .{
        .ta = ta,
        .allocator = allocator,
        .mutex = .{},
        .messages = std.ArrayList(buffer_message).init(a),
        .data = std.AutoHashMap(buffer_message, buffer_data).init(a),
    };
}

pub fn deinit() void {
    buffer.messages.deinit();
    var iter = buffer.data.iterator();
    while (iter.next()) |e| {
        const bd: buffer_data = e.value_ptr.*;
        switch (bd) {
            buffer_data.chunk_gen => |d| buffer.allocator.free(d.chunk_data),
            buffer_data.chunk_mesh => |d| buffer.allocator.destroy(d.chunk),
            buffer_data.chunk_copy => |d| buffer.allocator.destroy(d.chunk),
            else => {},
        }
    }
    buffer.data.deinit();
    buffer.allocator.destroy(buffer);
}

pub fn write_message(message: buffer_message) !void {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    try buffer.messages.append(message);
}

pub fn new_message(msg_type: buffer_message_type) buffer_message {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    if (id >= std.math.maxInt(u64)) {
        id = 0;
    }
    id += 1;
    return .{
        .id = id,
        .ts = std.time.milliTimestamp(),
        .type = msg_type,
    };
}

pub fn next_message() ?buffer_message {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    if (buffer.messages.items.len == 0) return null;
    return buffer.messages.orderedRemove(0);
}

pub fn put_data(msg: buffer_message, bd: buffer_data) !void {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    try buffer.data.put(msg, bd);
}

pub fn get_data(msg: buffer_message) ?buffer_data {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    if (buffer.data.fetchRemove(msg)) |kv| {
        return kv.value;
    }
    return null;
}

pub const ProgressReport = struct {
    done: bool,
    percent: f16,
};

pub const ProgressTracker = struct {
    num_started: usize,
    num_completed: usize,
    pub fn completeOne(self: *ProgressTracker) struct { bool, usize, usize } {
        buffer.mutex.lock();
        defer buffer.mutex.unlock();
        if (self.num_completed == self.num_started) std.debug.print(
            "tried to complete too many...{}/{}\n",
            .{
                self.num_started,
                self.num_completed + 1,
            },
        );
        self.num_completed += 1;
        std.debug.print(
            "self.num_started: {} self.num_completed: {}\n",
            .{
                self.num_started,
                self.num_completed,
            },
        );
        return .{
            self.num_started == self.num_completed,
            self.num_started,
            self.num_completed,
        };
    }
};

const done_flag = 0x1;
const demo_chunk_flag = 0x2;

pub fn set_progress(msg: *buffer_message, done: bool, percentage: f16) void {
    if (done) msg.flags = msg.flags | done_flag;
    msg.data = @bitCast(percentage);
}

pub fn progress_report(msg: buffer_message) ProgressReport {
    return .{
        .done = (msg.flags & done_flag) != 0x0,
        .percent = @bitCast(msg.data),
    };
}

pub fn set_demo_chunk(msg: *buffer_message) void {
    msg.flags = msg.flags | demo_chunk_flag;
}

pub fn is_demo_chunk(msg: buffer_message) !bool {
    if (msg.type != .chunk_gen) return BufferErr.Invalid;
    return (msg.flags & demo_chunk_flag) != 0x0;
}
