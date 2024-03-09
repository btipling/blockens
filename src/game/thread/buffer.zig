const std = @import("std");
const chunk = @import("../chunk.zig");

var buffer: *Buffer = undefined;

pub const BufferErr = error{
    Invalid,
};

pub const buffer_message_type = enum {
    chunk_gen,
    chunk_mesh,
};

pub const buffer_message = packed struct {
    id: i64 = 0,
    type: buffer_message_type,
    flags: u16 = 0,
    data: u16 = 0,
};

const Buffer = struct {
    ta: std.heap.ThreadSafeAllocator,
    allocator: std.mem.Allocator,
    msg_mutex: std.Thread.Mutex,
    messages: std.ArrayList(buffer_message),
    chunk_gen_mutex: std.Thread.Mutex,
    chunk_gens: std.AutoHashMap(buffer_message, []i32),
    chunk_mesh_mutex: std.Thread.Mutex,
    chunk_meshes: std.AutoHashMap(buffer_message, *chunk.Chunk),
};

pub fn init(allocator: std.mem.Allocator) void {
    var ta: std.heap.ThreadSafeAllocator = .{
        .child_allocator = allocator,
    };
    var a = ta.allocator();
    buffer = a.create(Buffer);
    buffer.* = .{
        .ta = ta,
        .allocator = allocator,
        .msg_mutex = .{},
        .messages = std.ArrayList(buffer_message).init(a),
        .chunk_gen_mutex = .{},
        .chunk_gens = std.AutoHashMap(buffer_message, []i32).init(a),
        .chunk_mesh_mutex = .{},
        .chunk_meshes = std.AutoHashMap(buffer_message, *chunk.Chunk).init(a),
    };
}

pub fn deinit() void {
    buffer.messages.deinit();
    var chunk_gen_iter = buffer.chunk_gens.valueIterator();
    while (chunk_gen_iter.next()) |c_d| {
        buffer.allocator.free(c_d.*);
    }
    buffer.chunk_gens.deinit();

    var chunk_mesh_iter = buffer.chunk_meshes.valueIterator();
    while (chunk_mesh_iter.next()) |c| {
        buffer.allocator.destroy(c.*);
    }
    buffer.chunk_meshes.deinit();
    buffer.allocator.destroy(buffer);
}

pub fn write_message(message: buffer_message) !void {
    buffer.msg_mutex.lock();
    defer buffer.msg_mutex.unlock();
    try buffer.messages.append(message);
}

pub fn new_message(msg_type: buffer_message_type) buffer_message {
    return .{
        .id = std.time.milliTimestamp(),
        .type = msg_type,
    };
}

pub fn has_message() bool {
    buffer.msg_mutex.lock();
    defer buffer.msg_mutex.unlock();
    return buffer.messages.items.len > 0;
}

pub fn next_message() ?buffer_message {
    buffer.msg_mutex.lock();
    defer buffer.msg_mutex.unlock();
    if (buffer.messages.items.len == 0) return null;
    return buffer.messages.orderedRemove(0);
}

pub fn put_chunk_gen_data(msg: buffer_message, chunk_data: []i32) !void {
    buffer.chunk_gen_mutex.lock();
    defer buffer.chunk_gen_mutex.unlock();
    if (msg.type != .chunk_gen) return BufferErr.Invalid;
    try buffer.chunk_gens.put(msg, chunk_data);
}

pub fn get_chunk_gen_data(msg: buffer_message) ?[]i32 {
    buffer.chunk_gen_mutex.lock();
    defer buffer.chunk_gen_mutex.unlock();
    if (msg.type != .chunk_gen) return null;
    return buffer.chunk_gens.fetchRemove(msg);
}

pub fn put_chunk_mesh_data(msg: buffer_message, chunk_val: *chunk.Chunk) !void {
    buffer.chunk_mesh_mutex.lock();
    defer buffer.chunk_mesh_mutex.unlock();
    if (msg.type != .chunk_mesh) return BufferErr.Invalid;
    try buffer.chunk_meshes.put(msg, chunk_val);
}

pub fn get_chunk_mesh_data(msg: buffer_message) ?*chunk.Chunk {
    buffer.chunk_mesh_mutex.lock();
    defer buffer.chunk_mesh_mutex.unlock();
    if (msg.type != .chunk_mesh) return null;
    return buffer.chunk_meshes.fetchRemove(msg);
}

pub const ProgressReport = struct {
    done: bool,
    percent: f16,
};

const done_flag = 0x1;
const demo_chunk_flag = 0x2;

pub fn set_progress(msg: *buffer_message, done: bool, percentage: f16) void {
    if (done) msg.flags = msg.flags | done_flag;
    msg.data = @intFromFloat(percentage);
}

pub fn progress_report(msg: buffer_message) ProgressReport {
    return .{
        .done = (msg.flags & done_flag) != 0x0,
        .percent = @floatCast(msg.data),
    };
}

pub fn is_demo_chunk(msg: buffer_message) bool {
    if (msg.type != .chunk_gen) return BufferErr.Invalid;
    return (msg.flags & demo_chunk_flag) != 0x0;
}
