const lightingData = struct {
    ambient: [4]f32,
};

pub fn initLightingShaderStorageBufferObject(
    block_binding_point: u32,
) u32 {
    const ld: lightingData = .{
        .ambient = .{ 1, 1, 1, 1 },
    };
    var ssbo: u32 = undefined;
    gl.genBuffers(1, &ssbo);
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);

    const struct_size = @sizeOf(lightingData);
    const size = @as(isize, @intCast(struct_size));
    gl.bufferData(gl.SHADER_STORAGE_BUFFER, size, &ld, gl.DYNAMIC_DRAW);
    gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, block_binding_point, ssbo);
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, 0);
    return ssbo;
}

pub fn updateLightingShaderStorageBufferObject(
    ssbo: u32,
    offset: usize,
    data: @Vector(4, f32),
) void {
    const ld: lightingData = .{
        .ambient = data,
    };
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);

    const struct_size = @sizeOf(lightingData);
    const size: isize = @intCast(struct_size);
    const buffer_offset: isize = @intCast(offset * struct_size);
    gl.bufferSubData(gl.SHADER_STORAGE_BUFFER, buffer_offset, size, &ld);
}

const gl = @import("zopengl").bindings;
