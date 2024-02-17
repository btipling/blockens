const std = @import("std");

pub const ShaderGen = struct {
    // genVertexShader - call ower owns the returned slice and must free it
    pub fn genVertexShader(allocator: std.mem.Allocator) ![:0]u8 {
        const buf = std.ArrayListUnmanaged(u8);
        try buf.append(allocator, "#version 330 core\n");
        try buf.append(allocator, "layout (location = 0) in vec3 position;\n\n");
        try buf.append(allocator, "void main()\n");
        try buf.append(allocator, "{\n");
        try buf.append(allocator, "    gl_Position = vec4(position, 1.0);\n");
        try buf.append(allocator, "}\n");
        const ownedSentinelSlice = try buf.toOwnedSliceSentinel(allocator, 0);
        std.debug.print("generated vertex shader: \n {d}\n", .{ownedSentinelSlice});
        return ownedSentinelSlice;
    }

    // genFragmentShader - call ower owns the returned slice
    pub fn genFragmentShader(allocator: std.mem.Allocator) ![:0]u8 {
        const buf = std.ArrayListUnmanaged(u8);
        try buf.append(allocator, "#version 330 core\n");
        try buf.append(allocator, "out vec4 FragColor;\n\n");
        try buf.append(allocator, "void main()\n");
        try buf.append(allocator, "{\n");
        // magenta to highlight shader without materials
        try buf.append(allocator, "    FragColor = vec4(1.0, 0.0, 1.0, 1.0);\n");
        try buf.append(allocator, "}\n");
        const ownedSentinelSlice = try buf.toOwnedSliceSentinel(allocator, 0);
        std.debug.print("generated fragment shader: \n {d}\n", .{ownedSentinelSlice});
        return ownedSentinelSlice;
    }
};
