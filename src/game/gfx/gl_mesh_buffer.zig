pub const meshVertexData = struct {
    attr_data: [4]u32 = undefined,
    attr_translation: [4]f32 = undefined,
};

// About 200MB preallocated.
const preallocated_mem_size: usize = @sizeOf(meshVertexData) * 16 * 1024 * 1024;

pub fn initMeshShaderStorageBufferObject(block_binding_point: u32) u32 {
    var ssbo: u32 = undefined;
    gl.genBuffers(1, &ssbo);
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);

    gl.bufferData(gl.SHADER_STORAGE_BUFFER, preallocated_mem_size, null, gl.DYNAMIC_DRAW);
    gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, block_binding_point, ssbo);
    return ssbo;
}

pub fn addData(ssbo: u32, offset: usize, data: []meshVertexData) usize {
    const data_ptr: *const anyopaque = data.ptr;

    const struct_size: isize = @intCast(@sizeOf(meshVertexData));
    const size: isize = @intCast(data.len * struct_size);
    const buffer_offset: isize = @intCast(offset);
    if (size + buffer_offset > preallocated_mem_size) @panic("SSBO allocation fault");

    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);
    gl.bufferSubData(gl.SHADER_STORAGE_BUFFER, buffer_offset, size, data_ptr);
    return @intCast(buffer_offset + size);
}

pub fn clearData(ssbo: u32) void {
    std.debug.print("clearing?\n", .{});
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);
    gl.bufferData(gl.SHADER_STORAGE_BUFFER, preallocated_mem_size, null, gl.DYNAMIC_DRAW);
}

const gl = @import("zopengl").bindings;
const std = @import("std");
const gfx = @import("gfx.zig");
