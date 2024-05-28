// This is a thing to build an SSBO buffer with vertices data so they don't have to be sent via attribute variables

const MeshData = @This();

ssbo: u32 = 0,
mesh_binding_point: u32 = constants.MeshDataBindingPoint,
offset: usize = 0,

pub fn init(self: *MeshData, ssbos: *std.AutoHashMap(u32, u32)) void {
    if (ssbos.contains(self.mesh_binding_point)) return;
    const new_ssbo = gl.mesh_buffer.initMeshShaderStorageBufferObject(
        self.mesh_binding_point,
    );
    self.ssbo = new_ssbo;
    ssbos.put(self.mesh_binding_point, new_ssbo) catch @panic("OOM");
}

pub const allocData = struct {
    index: usize,
    size: usize,
    capacity: usize,
};

const min_alloc_offset = 250;
const max_alloc_offset = chunk.sub_chunk.sub_chunk_size;

pub fn addData(self: *MeshData, data: []gl.mesh_buffer.meshVertexData) allocData {
    self.offset = gl.mesh_buffer.addData(self.ssbo, self.offset, data);
    const obj_size = @sizeOf(gl.mesh_buffer.meshVertexData);
    // TODO: enable editing
    // const alloc_capacity_size: usize = @min(max_alloc_offset, (data.len + @mod(data.len, min_alloc_offset)) * obj_size);

    const ad: allocData = .{
        .index = self.offset,
        .size = obj_size * data.len,
        .capacity = obj_size * data.len,
    };

    return ad;
}

pub fn clear(self: *MeshData) void {
    gl.mesh_buffer.clearData(self.ssbo);
}

const std = @import("std");
pub const gl = @import("gl.zig");
pub const constants = @import("gfx_constants.zig");
const block = @import("../block/block.zig");
const chunk = block.chunk;
