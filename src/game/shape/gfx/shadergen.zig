const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const math = @import("../../math/math.zig");

pub const TransformMatName: []const u8 = "transform";
pub const UBOName: []const u8 = "DataBlock";
pub const UBOMatName: []const u8 = "dataTransform";

pub const ShaderGen = struct {
    pub const vertexShaderConfig = struct {
        debug: bool = false,
        has_uniform_mat: bool = false,
        has_ubo: bool = false,
        has_texture_coords: bool = false,
        has_normals: bool = false,
        scale: ?math.vecs.Vflx4 = null,
        rotation: ?math.vecs.Vflx4 = null,
        translation: ?math.vecs.Vflx4 = null,
    };

    pub const fragmentShaderConfig = struct {
        debug: bool = false,
        has_texture: bool = false,
        has_texture_coords: bool = false,
        has_normals: bool = false,
        color: ?math.vecs.Vflx4 = null,
    };

    // genVertexShader - call ower owns the returned slice and must free it
    pub fn genVertexShader(allocator: std.mem.Allocator, cfg: vertexShaderConfig) ![:0]const u8 {
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(allocator);

        var inline_mat: ?zm.Mat = null;
        {
            var m = zm.identity();
            if (cfg.translation) |t| {
                m = zm.mul(m, zm.translationV(t.value));
                inline_mat = m;
            }
            if (cfg.scale) |s| {
                m = zm.mul(m, zm.scalingV(s.value));
                inline_mat = m;
            }
            if (cfg.rotation) |r| {
                m = zm.mul(m, zm.quatToMat(r.value));
                inline_mat = m;
            }
        }
        var location: u8 = 0;
        try buf.appendSlice(allocator, "#version 330 core\n");
        {
            var line = try attribute_location(location, "position", .vec3);
            try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
            location += 1;
            if (cfg.has_texture_coords) {
                line = try attribute_location(location, "eTexCoord", .vec2);
                try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
                location += 1;
            }
            if (cfg.has_normals) {
                line = try attribute_location(location, "normal", .vec3);
                try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
                location += 1;
            }
        }
        try buf.appendSlice(allocator, "\n");
        if (cfg.has_texture_coords) {
            try buf.appendSlice(allocator, "\nout vec2 TexCoord;\n");
        }
        if (cfg.has_normals) {
            try buf.appendSlice(allocator, "\nflat out vec3 fragNormal;\n");
        }
        if (cfg.has_uniform_mat) {
            try buf.appendSlice(allocator, "\nuniform mat4 ");
            try buf.appendSlice(allocator, TransformMatName);
            try buf.appendSlice(allocator, ";\n\n");
        }
        if (cfg.has_ubo) {
            try buf.appendSlice(allocator, "\nlayout(std140) uniform ");
            try buf.appendSlice(allocator, UBOName);
            try buf.appendSlice(allocator, " {\n    mat4 ");
            try buf.appendSlice(allocator, UBOMatName);
            try buf.appendSlice(allocator, ";\n};\n\n");
        }
        try buf.appendSlice(allocator, "void main()\n");
        try buf.appendSlice(allocator, "{\n");
        try buf.appendSlice(allocator, "    vec4 pos;\n");
        try buf.appendSlice(allocator, "    pos = vec4(position.xyz, 1.0);\n");
        if (inline_mat) |m| {
            const mr = zm.matToArr(m);
            var line = try vec4_to_buf("    vec4 c0 = vec4({d}, {d}, {d}, {d});\n", mr[0], mr[1], mr[2], mr[3]);
            try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
            line = try vec4_to_buf("    vec4 c1 = vec4({d}, {d}, {d}, {d});\n", mr[4], mr[5], mr[6], mr[7]);
            try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
            line = try vec4_to_buf("    vec4 c2 = vec4({d}, {d}, {d}, {d});\n", mr[8], mr[9], mr[10], mr[11]);
            try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
            line = try vec4_to_buf("    vec4 c3 = vec4({d}, {d}, {d}, {d});\n", mr[12], mr[13], mr[14], mr[15]);
            try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
            try buf.appendSlice(allocator, "    mat4 inline_transform = mat4(c0, c1, c2, c3);\n");
            try buf.appendSlice(allocator, "    pos = inline_transform * pos;\n");
        }
        if (cfg.has_uniform_mat) {
            try buf.appendSlice(allocator, "    pos = ");
            try buf.appendSlice(allocator, TransformMatName);
            try buf.appendSlice(allocator, " * pos;\n");
        }
        if (cfg.has_ubo) {
            try buf.appendSlice(allocator, "    pos = ");
            try buf.appendSlice(allocator, UBOMatName);
            try buf.appendSlice(allocator, " * pos;\n");
        }
        try buf.appendSlice(allocator, "    gl_Position = pos;\n");
        if (cfg.has_texture_coords) {
            try buf.appendSlice(allocator, "    TexCoord = eTexCoord;\n");
        }
        if (cfg.has_normals) {
            try buf.appendSlice(allocator, "    fragNormal = normal;\n");
        }
        try buf.appendSlice(allocator, "}\n");
        const ownedSentinelSlice: [:0]const u8 = try buf.toOwnedSliceSentinel(allocator, 0);
        if (cfg.debug) std.debug.print("generated vertex shader: \n {s}\n", .{ownedSentinelSlice});
        return ownedSentinelSlice;
    }

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
            const line = try vec4_to_buf("    vec4 Color = vec4({d}, {d}, {d}, {d});\n", c.value[0], c.value[1], c.value[2], c.value[3]);
            try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
        } else {
            try buf.appendSlice(allocator, "    vec Color = vec4(1.0, 0.0, 1.0, 1.0);\n");
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

    const varType = enum {
        vec2,
        vec3,
        vec4,
    };

    fn attribute_location(
        loc: u8,
        comptime name: []const u8,
        var_type: varType,
    ) ![250:0]u8 {
        var buffer: [250:0]u8 = [_:0]u8{0} ** 250;
        const var_type_name: []const u8 = switch (var_type) {
            .vec2 => "vec2",
            .vec3 => "vec3",
            .vec4 => "vec4",
        };
        _ = try std.fmt.bufPrint(&buffer, "layout (location = {d}) in {s} {s};\n", .{ loc, var_type_name, name });
        return buffer;
    }

    fn vec4_to_buf(
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
