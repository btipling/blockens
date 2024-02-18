const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const math = @import("../../math/math.zig");

pub const ShaderGen = struct {
    pub const vertexShaderConfig = struct {
        has_uniform_mat: bool = false,
        inline_mat: ?zm.Mat = null,
    };

    pub const fragmentShaderConfig = struct {
        color: ?math.vecs.Vflx4 = null,
    };

    // genVertexShader - call ower owns the returned slice and must free it
    pub fn genVertexShader(allocator: std.mem.Allocator, cfg: vertexShaderConfig) ![:0]const u8 {
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(allocator);

        try buf.appendSlice(allocator, "#version 330 core\n");
        try buf.appendSlice(allocator, "layout (location = 0) in vec3 position;\n\n");
        if (cfg.has_uniform_mat) {
            try buf.appendSlice(allocator, "\n\nuniform mat4 transform;\n\n");
        }
        try buf.appendSlice(allocator, "void main()\n");
        try buf.appendSlice(allocator, "{\n");
        try buf.appendSlice(allocator, "    vec4 pos;\n");
        try buf.appendSlice(allocator, "    pos = vec4(position.xyz, 1.0);\n");
        if (cfg.has_uniform_mat) {
            try buf.appendSlice(allocator, "    pos = transform * pos;\n");
        }
        try buf.appendSlice(allocator, "    gl_Position = pos;\n");
        try buf.appendSlice(allocator, "}\n");
        const ownedSentinelSlice: [:0]const u8 = try buf.toOwnedSliceSentinel(allocator, 0);
        std.debug.print("generated vertex shader: \n {s}\n", .{ownedSentinelSlice});
        return ownedSentinelSlice;
    }

    // genFragmentShader - call ower owns the returned slice
    pub fn genFragmentShader(allocator: std.mem.Allocator, cfg: fragmentShaderConfig) ![:0]const u8 {
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(allocator);

        try buf.appendSlice(allocator, "#version 330 core\n");
        try buf.appendSlice(allocator, "out vec4 FragColor;\n\n");
        try buf.appendSlice(allocator, "void main()\n");
        try buf.appendSlice(allocator, "{\n");
        // magenta to highlight shader without materials
        if (cfg.color) |c| {
            const line = try vec4ToBuf("    FragColor = vec4({d}, {d}, {d}, {d});\n", c.value[0], c.value[1], c.value[2], c.value[3]);
            try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
        } else {
            try buf.appendSlice(allocator, "    FragColor = vec4(1.0, 0.0, 1.0, 1.0);\n");
        }
        try buf.appendSlice(allocator, "}\n");
        const ownedSentinelSlice: [:0]const u8 = try buf.toOwnedSliceSentinel(allocator, 0);
        std.debug.print("generated fragment shader: \n {s}\n", .{ownedSentinelSlice});
        return ownedSentinelSlice;
    }

    fn vec4ToBuf(
        comptime fmt: []const u8,
        v0: gl.Float,
        v1: gl.Float,
        v2: gl.Float,
        v3: gl.Float,
    ) ![250:0]u8 {
        var buffer: [250:0]u8 = [_:0]u8{0} ** 250;
        _ = try std.fmt.bufPrint(&buffer, fmt, .{ v0, v1, v2, v3 });
        return buffer;
    }
};
