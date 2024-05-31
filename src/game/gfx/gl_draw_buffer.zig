pub const drawData = struct {
    offset: u32 = undefined,
    count: u32 = undefined,
    translation: [4]f32 = undefined,
};

const preallocated_mem_size: usize = @sizeOf(drawData) * 16 * 1024 * 1024;

pub fn initDrawShaderStorageBufferObject(block_binding_point: u32) u32 {
    var ssbo: u32 = undefined;
    gl.genBuffers(1, &ssbo);
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);
    const flags = gl.MAP_WRITE_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT;
    gl.namedBufferStorage(ssbo, preallocated_mem_size, null, flags);
    gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, block_binding_point, ssbo);
    return ssbo;
}

pub fn addDrawData(ssbo: u32, offset: usize, pd: []const drawData) void {
    const dataptr: []const u8 = std.mem.sliceAsBytes(pd);

    const struct_size: isize = @intCast(@sizeOf(drawData));
    const size: isize = @intCast(pd.len * struct_size);
    const buffer_offset: isize = @intCast(offset);

    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);
    const flags = gl.MAP_WRITE_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT;
    const gl_ptr = gl.mapBufferRange(gl.SHADER_STORAGE_BUFFER, buffer_offset, size, flags);
    std.debug.assert(gl_ptr != null);
    const dest = @as([*]u8, @ptrCast(gl_ptr orelse unreachable));
    @memcpy(dest, dataptr);
    if (gl.unmapBuffer(gl.SHADER_STORAGE_BUFFER) == 0) @panic("oh no");
}

const gl = @import("zopengl").bindings;
const std = @import("std");
const gfx = @import("gfx.zig");
