// This is a thing to build an SSBO buffer with vertices data so they don't have to be sent via attribute variables

const MeshData = @This();

mesh_binding_point: u32 = constants.MeshDataBindinggPoint,

pub fn init(self: *MeshData, vertices: []const [3]f32, ssbos: *std.AutoHashMap(u32, u32)) void {
    var buf: [1000 * @sizeOf(gl.mesh_buffer.meshData)]u8 = undefined;
    var allocator = std.heap.FixedBufferAllocator.init(buf[0..]);

    var md = std.ArrayList(gl.mesh_buffer.meshData).init(allocator.allocator());
    for (vertices) |v| {
        md.append(.{
            .vertices = .{
                v[0],
                v[1],
                v[2],
                1,
            },
        }) catch @panic("OOM");
    }

    if (ssbos.contains(self.mesh_binding_point)) return;
    const new_ssbo = gl.mesh_buffer.initMeshShaderStorageBufferObject(
        allocator.allocator(),
        self.mesh_binding_point,
        md.items,
    );
    ssbos.put(self.mesh_binding_point, new_ssbo) catch @panic("OOM");
}

const std = @import("std");
pub const gl = @import("gl.zig");
pub const constants = @import("gfx_constants.zig");
