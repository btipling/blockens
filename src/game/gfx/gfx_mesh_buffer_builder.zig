// This is a thing to build an SSBO buffer with vertices data so they don't have to be sent via attribute variables

const MeshData = @This();

mesh_binding_point: u32 = constants.MeshDataBindinggPoint,

pub fn init(_: std.mem.Allocator) MeshData {
    return .{};
}

pub fn deinit(_: *MeshData, _: std.mem.Allocator) void {}

pub fn add(self: *MeshData, _: [][3]f32, ssbos: *std.AutoHashMap(u32, u32)) void {
    const md = [_]gl.mesh_buffer.meshData{};

    if (ssbos.contains(self.mesh_binding_point)) return;
    const new_ssbo = gl.mesh_buffer.initMeshShaderStorageBufferObject(
        self.mesh_binding_point,
        &md,
    );
    ssbos.put(self.mesh_binding_point, new_ssbo) catch @panic("OOM");
}

const std = @import("std");
pub const gl = @import("gl.zig");
pub const constants = @import("gfx_constants.zig");
