// This is a thing to build an SSBO buffer with vertices data so they don't have to be sent via attribute variables

const MeshData = @This();

buffer_ssbo: u32 = 0,
draw_ssbo: u32 = 0,
mesh_binding_point: u32,
draw_binding_point: u32,
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
    if (!ssbos.contains(self.draw_binding_point)) {
        const new_ssbo = gl.draw_buffer.initDrawShaderStorageBufferObject(
            self.draw_binding_point,
        );
        self.draw_ssbo = new_ssbo;
        std.debug.print("allocator ssbo: {d} binding point: {d}\n", .{ new_ssbo, self.draw_binding_point });
        ssbos.put(self.draw_binding_point, new_ssbo) catch @panic("OOM");
    }
}

pub const allocData = struct {
    index: usize,
    size: usize,
    capacity: usize,
};

const max_alloc_offset = chunk.sub_chunk.sub_chunk_size;

pub fn addMeshData(self: *MeshData, data: []gl.mesh_buffer.meshVertexData, translation: @Vector(4, f32)) allocData {
    const index = self.offset;
    const actual_offset = gl.mesh_buffer.addData(self.buffer_ssbo, self.offset, data);

    const obj_size = @sizeOf(gl.mesh_buffer.meshVertexData);
    const actual_consumed_space = obj_size * data.len;

    var pd: [1]gl.draw_buffer.drawData = .{
        .{
            .draw_pointer = [4]u32{ @intCast(self.additions), 0, 0, 0 },
            .translation = translation,
        },
    };
    gl.draw_buffer.addDrawData(
        self.draw_ssbo,
        self.additions * @sizeOf(gl.draw_buffer.drawData),
        pd[0..],
    );
    self.additions += 1;

    // Allocate some extra space to allow for some edits without reallocating.
    const extra_space = obj_size * 100;
    const alloc_capacity_size: usize = @min(max_alloc_offset, actual_consumed_space + extra_space);
    self.offset = self.offset + alloc_capacity_size;
    // Assert that we don't set offset to less than we actually needed.
    // std.debug.assert(actual_offset <= self.offset);
    self.offset = actual_offset;

    const ad: allocData = .{
        .index = index,
        .size = actual_consumed_space,
        .capacity = alloc_capacity_size,
    };

    return ad;
}

pub fn clear(self: *MeshData) void {
    self.offset = 0;
    self.clearDraws();
}

pub fn clearDraws(self: *MeshData) void {
    self.additions = 0;
}

const std = @import("std");
pub const gl = @import("gl.zig");
pub const constants = @import("gfx_constants.zig");
const block = @import("../block/block.zig");
const chunk = block.chunk;
