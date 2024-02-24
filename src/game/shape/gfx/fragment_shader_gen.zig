const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const math = @import("../../math/math.zig");
const shader_helpers = @import("shader_helpers.zig");

pub const FragmentShaderGen = struct {
    pub const fragmentShaderConfig = struct {
        debug: bool = false,
        has_texture: bool = false,
        has_texture_coords: bool = false,
        has_normals: bool = false,
        color: ?math.vecs.Vflx4 = null,
    };

    // genFragmentShader - call ower owns the returned slice
    pub fn genFragmentShader(allocator: std.mem.Allocator, cfg: fragmentShaderConfig) ![:0]const u8 {
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(allocator);

        try buf.appendSlice(allocator, "#version 330 core\n");
        try buf.appendSlice(allocator, "out vec4 FragColor;\n");
        if (cfg.has_texture_coords) {
            try buf.appendSlice(allocator, "\nin vec2 TexCoord;\n");
        }
        if (cfg.has_normals) {
            try buf.appendSlice(allocator, "\nflat in vec3 fragNormal;\n");
        }
        if (cfg.has_texture) {
            try buf.appendSlice(allocator, "\nuniform sampler2D texture1;\n");
        }
        try buf.appendSlice(allocator, "\nvoid main()\n");
        try buf.appendSlice(allocator, "{\n");
        // magenta to highlight shader without materials
        if (cfg.color) |c| {
            const line = try shader_helpers.vec4_to_buf("    vec4 Color = vec4({d}, {d}, {d}, {d});\n", c.value[0], c.value[1], c.value[2], c.value[3]);
            try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
        } else {
            try buf.appendSlice(allocator, "    vec4 Color = vec4(1.0, 0.0, 1.0, 1.0);\n");
        }
        if (cfg.has_texture) {
            try buf.appendSlice(allocator, "    vec4 textureColor = texture(texture1, TexCoord);\n");
            try buf.appendSlice(allocator, "    vec4 finalColor = mix(Color, textureColor, textureColor.a);\n");
            try buf.appendSlice(allocator, "    FragColor = finalColor;\n");
        } else {
            try buf.appendSlice(allocator, "    FragColor = Color;\n");
        }
        try buf.appendSlice(allocator, "}\n");
        const ownedSentinelSlice: [:0]const u8 = try buf.toOwnedSliceSentinel(allocator, 0);
        if (cfg.debug) std.debug.print("generated fragment shader: \n {s}\n", .{ownedSentinelSlice});
        return ownedSentinelSlice;
    }
};
