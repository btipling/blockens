pub const meshData = struct {
    vertices: [4]f32,
};

pub fn initMeshShaderStorageBufferObject(
    allocator: std.mem.Allocator,
    block_binding_point: u32,
    data: []meshData,
) u32 {
    var mdl = std.ArrayListUnmanaged(meshData){};
    defer mdl.deinit(allocator);
    for (data) |d| {
        mdl.append(allocator, d) catch unreachable;
    }
    var ssbo: u32 = undefined;
    gl.genBuffers(1, &ssbo);
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);

    const data_ptr: *const anyopaque = mdl.items.ptr;
    const struct_size = @sizeOf(meshData);
    const size = @as(isize, @intCast(mdl.items.len * struct_size));
    gl.bufferData(gl.SHADER_STORAGE_BUFFER, size, data_ptr, gl.DYNAMIC_DRAW);
    gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, block_binding_point, ssbo);
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, 0);
    return ssbo;
}

const gl = @import("zopengl").bindings;
const std = @import("std");
const gfx = @import("gfx.zig");
