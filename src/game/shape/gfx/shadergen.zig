const std = @import("std");

pub const ShaderGen = struct {
    // genVertexShader - call ower owns the returned slice and must free it
    pub fn genVertexShader(allocator: std.mem.Allocator) ![:0]const u8 {
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(allocator);

        try buf.appendSlice(allocator, "#version 330 core\n");
        try buf.appendSlice(allocator, "layout (location = 0) in vec3 position;\n\n");
        try buf.appendSlice(allocator, "\n\nuniform mat4 transform;\n\n");
        try buf.appendSlice(allocator, "void main()\n");
        try buf.appendSlice(allocator, "{\n");
        try buf.appendSlice(allocator, "    gl_Position = transform * vec4(position.xyz, 1.0);\n");
        try buf.appendSlice(allocator, "}\n");
        const ownedSentinelSlice: [:0]const u8 = try buf.toOwnedSliceSentinel(allocator, 0);
        std.debug.print("generated vertex shader: \n {s}\n", .{ownedSentinelSlice});
        return ownedSentinelSlice;
    }

    // genFragmentShader - call ower owns the returned slice
    pub fn genFragmentShader(allocator: std.mem.Allocator) ![:0]const u8 {
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(allocator);

        try buf.appendSlice(allocator, "#version 330 core\n");
        try buf.appendSlice(allocator, "out vec4 FragColor;\n\n");
        try buf.appendSlice(allocator, "void main()\n");
        try buf.appendSlice(allocator, "{\n");
        // magenta to highlight shader without materials
        try buf.appendSlice(allocator, "    FragColor = vec4(1.0, 0.0, 1.0, 1.0);\n");
        try buf.appendSlice(allocator, "}\n");
        const ownedSentinelSlice: [:0]const u8 = try buf.toOwnedSliceSentinel(allocator, 0);
        std.debug.print("generated fragment shader: \n {s}\n", .{ownedSentinelSlice});
        return ownedSentinelSlice;
    }
};
