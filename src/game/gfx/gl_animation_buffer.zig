const animationKeyFrame = struct {
    data: [4]f32,
    scale: [4]f32,
    rotation: [4]f32,
    translation: [4]f32,
};

pub fn initAnimationShaderStorageBufferObject(
    block_binding_point: u32,
    data: []gfx.Animation.AnimationKeyFrame,
) u32 {
    var ar = std.ArrayListUnmanaged(animationKeyFrame){};
    defer ar.deinit(game.state.allocator);
    for (data) |d| {
        ar.append(game.state.allocator, animationKeyFrame{
            .data = [4]f32{ d.frame, 0, 0, 0 },
            .scale = d.scale,
            .rotation = d.rotation,
            .translation = d.translation,
        }) catch unreachable;
    }
    var ssbo: u32 = undefined;
    gl.genBuffers(1, &ssbo);
    std.debug.print("animation storage ssbo: {d}\n", .{ssbo});
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);

    const data_ptr: *const anyopaque = ar.items.ptr;
    const struct_size = @sizeOf(animationKeyFrame);
    const size = @as(isize, @intCast(ar.items.len * struct_size));
    gl.bufferData(gl.SHADER_STORAGE_BUFFER, size, data_ptr, gl.DYNAMIC_DRAW);
    gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, block_binding_point, ssbo);
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, 0);
    return ssbo;
}

pub fn resizeAnimationShaderStorageBufferObject(ssbo: u32, num_frames: usize) void {
    var ar = std.ArrayListUnmanaged(animationKeyFrame){};
    defer ar.deinit(game.state.allocator);
    var i: usize = 0;
    while (i < num_frames) : (i += 1) {
        ar.append(game.state.allocator, .{
            .data = std.mem.zeroes([4]f32),
            .scale = std.mem.zeroes([4]f32),
            .rotation = std.mem.zeroes([4]f32),
            .translation = std.mem.zeroes([4]f32),
        }) catch @panic("OOM");
    }
    const data_ptr: *const anyopaque = ar.items.ptr;

    const struct_size = @sizeOf(animationKeyFrame);
    const size: isize = @intCast(ar.items.len * struct_size);
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);
    gl.bufferData(gl.SHADER_STORAGE_BUFFER, size, data_ptr, gl.DYNAMIC_DRAW);
}

pub fn addAnimationShaderStorageBufferData(
    ssbo: u32,
    offset: usize,
    data: []gfx.Animation.AnimationKeyFrame,
) void {
    var ar = std.ArrayListUnmanaged(animationKeyFrame){};
    defer ar.deinit(game.state.allocator);
    for (data) |d| {
        ar.append(game.state.allocator, animationKeyFrame{
            .data = [4]f32{ d.frame, 0, 0, 0 },
            .scale = d.scale,
            .rotation = d.rotation,
            .translation = d.translation,
        }) catch @panic("OOM");
    }
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);

    const data_ptr: *const anyopaque = ar.items.ptr;

    const struct_size = @sizeOf(animationKeyFrame);
    const size: isize = @intCast(ar.items.len * struct_size);
    const buffer_offset: isize = @intCast(offset * struct_size);
    gl.bufferSubData(gl.SHADER_STORAGE_BUFFER, buffer_offset, size, data_ptr);
}

const gl = @import("zopengl").bindings;
const std = @import("std");
const gfx = @import("gfx.zig");
const game = @import("../game.zig");
