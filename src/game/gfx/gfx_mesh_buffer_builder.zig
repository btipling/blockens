// This is a thing to build an SSBO buffer with vertices data so they don't have to be sent via attribute variables

const MeshData = @This();

buffer_ssbo: u32 = 0,
allocator_ssbo: u32 = 0,
mesh_binding_point: u32,
allocator_binding_point: u32,
offset: usize = 0,
additions: usize = 0,
with_allocation: bool = false,

pub fn init(self: *MeshData, ssbos: *std.AutoHashMap(u32, u32)) void {
    if (!ssbos.contains(self.mesh_binding_point)) {
        const new_ssbo = gl.mesh_buffer.initMeshShaderStorageBufferObject(
            self.mesh_binding_point,
        );
        self.buffer_ssbo = new_ssbo;
        std.debug.print("mesh ssbo: {d} binding point: {d}\n", .{ new_ssbo, self.mesh_binding_point });
        ssbos.put(self.mesh_binding_point, new_ssbo) catch @panic("OOM");
    }
    if (self.with_allocation) {
        if (!ssbos.contains(self.allocator_binding_point)) {
            const new_ssbo = gl.allocator_buffer.initAllocatorShaderStorageBufferObject(
                self.allocator_binding_point,
            );
            self.allocator_ssbo = new_ssbo;
            std.debug.print("allocator ssbo: {d} binding point: {d}\n", .{ new_ssbo, self.allocator_binding_point });
            ssbos.put(self.allocator_binding_point, new_ssbo) catch @panic("OOM");
        }
    }
}

pub const allocData = struct {
    index: usize,
    size: usize,
    capacity: usize,
};

const max_alloc_offset = chunk.sub_chunk.sub_chunk_size;

pub fn addData(self: *MeshData, data: []gl.mesh_buffer.meshVertexData) allocData {
    const index = self.offset;
    const actual_offset = gl.mesh_buffer.addData(self.buffer_ssbo, self.offset, data);

    const obj_size = @sizeOf(gl.mesh_buffer.meshVertexData);
    const actual_consumed_space = obj_size * data.len;
    // This math has to be correct:
    // std.debug.assert(actual_offset == self.offset + actual_consumed_space);

    // Allocate some extra space to allow for some edits without reallocating.
    const extra_space = obj_size * 100;
    const alloc_capacity_size: usize = @min(max_alloc_offset, actual_consumed_space + extra_space);
    self.offset = self.offset + alloc_capacity_size;
    // Assert that we don't set offset to less than we actually needed.
    // std.debug.assert(actual_offset <= self.offset);
    self.offset = actual_offset;
    var pd: [1]gl.allocator_buffer.pointerData = .{
        .{
            .offset = @intCast(self.additions),
            .count = 0,
        },
    };
    if (self.with_allocation) {
        gl.allocator_buffer.addPointers(
            self.allocator_ssbo,
            self.additions * @sizeOf(gl.allocator_buffer.pointerData),
            pd[0..],
        );
    }
    self.additions += 1;

    const ad: allocData = .{
        .index = index,
        .size = actual_consumed_space,
        .capacity = alloc_capacity_size,
    };

    return ad;
}

pub fn clear(self: *MeshData) void {
    self.offset = 0;
    self.additions = 0;
}

const std = @import("std");
pub const gl = @import("gl.zig");
pub const constants = @import("gfx_constants.zig");
const block = @import("../block/block.zig");
const chunk = block.chunk;
