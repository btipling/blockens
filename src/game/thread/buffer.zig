var id: u64 = 0;

var ta: std.heap.ThreadSafeAllocator = undefined;
var buffer: *Buffer = undefined;

pub const BufferErr = error{
    Invalid,
};

pub const buffer_message_type = enum(u8) {
    startup,
    chunk_gen,
    small_chunk_gen,
    chunk_mesh,
    lighting,
    lighting_cross_chunk,
    load_chunk,
    demo_descriptor_gen,
    demo_terrain_gen,
    world_descriptor_gen,
    world_terrain_gen,
    player_pos,
};

pub const buffer_data = union(buffer_message_type) {
    startup: startup_data,
    chunk_gen: chunk_gen_data,
    small_chunk_gen: small_chunk_gen_data,
    chunk_mesh: chunk_mesh_data,
    lighting: lightings_data,
    lighting_cross_chunk: lightings_data,
    load_chunk: load_chunk_data,
    demo_descriptor_gen: demo_descriptor_gen_data,
    demo_terrain_gen: demo_terrain_gen_data,
    world_descriptor_gen: world_descriptor_gen_data,
    world_terrain_gen: world_terrain_gen_data,
    player_pos: player_pos_data,
};

pub const buffer_message = packed struct {
    id: u64 = 0,
    ts: i64 = 0,
    type: u8,
    flags: u16 = 0,
    data: u16 = 0,
};

pub const startup_data = struct {
    done: bool = true,
};

pub const chunk_gen_data = struct {
    wp: chunk.worldPosition,
    chunk_data: []u32,
};

pub const small_chunk_gen_data = struct {
    chunk_data: []u32,
};

pub const chunk_mesh_data = struct {
    world: ?*blecs.ecs.world_t = null,
    entity: ?blecs.ecs.entity_t = null,
    empty: bool = false,
    chunk: *chunk.Chunk,
};

pub const lightings_data = struct {
    world_id: i32,
    x: i32,
    z: i32,
};

pub const load_chunk_data = struct {
    world_id: i32,
    x: i32,
    z: i32,
    wp_t: chunk.worldPosition,
    wp_b: chunk.worldPosition,
    cfg_t: ui.chunkConfig,
    cfg_b: ui.chunkConfig,
    exists: bool,
    start_game: bool,
};

pub const demo_descriptor_gen_data = struct {
    desc_root: *descriptor.root,
    offset_x: i32,
    offset_z: i32,
};

pub const world_descriptor_gen_data = struct {
    world_id: i32,
    descriptors: std.ArrayList(*descriptor.root),
};

pub const demo_terrain_gen_data = struct {
    desc_root: *descriptor.root,
    succeeded: bool,
    data: ?[]u32,
    position: @Vector(4, f32),
};

pub const world_terrain_gen_data = struct {
    world_id: i32,
    descriptors: std.ArrayList(*descriptor.root),
};

pub const player_pos_data = struct {};

pub const ChunkColumn = struct {
    x: i8,
    z: i8,
};

const Buffer = struct {
    ta: std.heap.ThreadSafeAllocator,
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,
    messages: std.ArrayList(buffer_message),
    data: std.AutoHashMap(buffer_message, buffer_data),
    updated_chunks: std.ArrayList(ChunkColumn),
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
        .updated_chunks = std.ArrayList(ChunkColumn).init(a),
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
            else => {},
        }
    }
    buffer.data.deinit();
    buffer.updated_chunks.deinit();
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
    const mt: u8 = @intFromEnum(msg_type);
    return .{
        .id = id,
        .ts = std.time.milliTimestamp(),
        .type = mt,
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

pub fn set_updated_chunks(uc: []ChunkColumn) void {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    buffer.updated_chunks.appendSlice(uc) catch @panic("OOM");
}

// caller owns memory
pub fn get_updated_chunks() []ChunkColumn {
    buffer.mutex.lock();
    defer buffer.mutex.unlock();
    const cc = buffer.updated_chunks.toOwnedSlice() catch @panic("OOM");
    buffer.updated_chunks.clearRetainingCapacity();
    return cc;
}

pub const ProgressReport = struct {
    done: bool,
    percent: f16,
};

pub const ProgressTracker = struct {
    num_started: usize,
    num_completed: usize,
    pub fn completeOne(self: *ProgressTracker, bmset: buffer_message, bd: buffer_data) void {
        var msg = bmset;
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
        const ns: f16 = @floatFromInt(self.num_started);
        const nd: f16 = @floatFromInt(self.num_completed);
        const pr: f16 = nd / ns;
        const done = self.num_started == self.num_completed;
        set_progress(
            &msg,
            done,
            pr,
        );
        buffer.data.put(msg, bd) catch @panic("OOM");
        buffer.messages.append(msg) catch @panic("unable to write message");
        if (done) ta.allocator().destroy(self);
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
    const mt: buffer_message_type = @enumFromInt(msg.type);
    if (mt != .chunk_gen) return BufferErr.Invalid;
    return (msg.flags & demo_chunk_flag) != 0x0;
}

const std = @import("std");
const state = @import("../state.zig");
const ui = @import("../ui.zig");
const blecs = @import("../blecs/blecs.zig");
const block = @import("../block/block.zig");
const chunk = block.chunk;
const descriptor = chunk.descriptor;
