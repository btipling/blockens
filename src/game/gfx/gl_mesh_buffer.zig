const meshVertexData = struct {
    attr_data: [4]u32,
    attr_transform: [4]f32,
};

// About 200MB preallocated.
const preallocated_mem_size: usize = @sizeOf(meshVertexData) * 6 * 1024 * 1024;

pub fn initMeshShaderStorageBufferObject(block_binding_point: u32) u32 {
    var ssbo: u32 = undefined;
    gl.genBuffers(1, &ssbo);
    std.debug.print("mesh storage ssbo: {d}\n", .{ssbo});
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);

    gl.bufferData(gl.SHADER_STORAGE_BUFFER, preallocated_mem_size, null, gl.STATIC_DRAW);
    gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, block_binding_point, ssbo);
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, 0);
    return ssbo;
}

const gl = @import("zopengl").bindings;
const std = @import("std");
const gfx = @import("gfx.zig");
