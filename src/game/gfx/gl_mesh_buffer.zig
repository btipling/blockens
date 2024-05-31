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
    const flags = gl.MAP_WRITE_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT;
    gl.namedBufferStorage(ssbo, preallocated_mem_size, null, flags);
    gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, block_binding_point, ssbo);
    return ssbo;
}

pub fn addData(ssbo: u32, offset: usize, data: []const meshVertexData) usize {
    const dataptr: []const u8 = std.mem.sliceAsBytes(data);

    const struct_size: isize = @intCast(@sizeOf(meshVertexData));
    const size: isize = @intCast(data.len * struct_size);
    const buffer_offset: isize = @intCast(offset);
    if (size + buffer_offset > preallocated_mem_size) @panic("SSBO allocation fault");

    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);
    const flags = gl.MAP_WRITE_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT;
    const gl_ptr = gl.mapBufferRange(gl.SHADER_STORAGE_BUFFER, buffer_offset, size, flags);
    std.debug.assert(gl_ptr != null);
    const dest = @as([*]u8, @ptrCast(gl_ptr orelse unreachable));
    @memcpy(dest, dataptr);
    if (gl.unmapBuffer(gl.SHADER_STORAGE_BUFFER) == 0) @panic("oh no");
    return @intCast(buffer_offset + size);
}

const gl = @import("zopengl").bindings;
const std = @import("std");
const gfx = @import("gfx.zig");
