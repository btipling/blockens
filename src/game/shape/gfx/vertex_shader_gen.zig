const std = @import("std");
const zm = @import("zmath");
const math = @import("../../math/math.zig");
const shader_constants = @import("shader_constants.zig");
const shader_helpers = @import("shader_helpers.zig");

pub const VertexShaderGen = struct {
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

    // genVertexShader - call ower owns the returned slice and must free it
    pub fn genVertexShader(allocator: std.mem.Allocator, cfg: vertexShaderConfig) ![:0]const u8 {
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(allocator);

        var inline_mat: ?zm.Mat = null;
        {
            var m = zm.identity();
            if (cfg.scale) |s| {
                m = zm.mul(m, zm.scalingV(s.value));
                inline_mat = m;
            }
            if (cfg.rotation) |r| {
                m = zm.mul(m, zm.quatToMat(r.value));
                inline_mat = m;
            }
            if (cfg.translation) |t| {
                m = zm.mul(m, zm.translationV(t.value));
                inline_mat = m;
            }
        }
        var location: u8 = 0;
        try buf.appendSlice(allocator, "#version 450 core\n");
        {
            var line = try shader_helpers.attribute_location(location, "position", .vec3);
            try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
            location += 1;
            if (cfg.has_texture_coords) {
                line = try shader_helpers.attribute_location(location, "eTexCoord", .vec2);
                try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
                location += 1;
            }
            if (cfg.has_normals) {
                line = try shader_helpers.attribute_location(location, "normal", .vec3);
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
            try buf.appendSlice(allocator, shader_constants.TransformMatName);
            try buf.appendSlice(allocator, ";\n\n");
        }
        if (cfg.has_ubo) {
            try buf.appendSlice(allocator, "\nlayout(std140) uniform ");
            try buf.appendSlice(allocator, shader_constants.UBOName);
            try buf.appendSlice(allocator, " {\n    mat4 ");
            try buf.appendSlice(allocator, shader_constants.UBOMatName);
            try buf.appendSlice(allocator, ";\n};\n\n");
        }
        try buf.appendSlice(allocator, "void main()\n");
        try buf.appendSlice(allocator, "{\n");
        try buf.appendSlice(allocator, "    vec4 pos;\n");
        try buf.appendSlice(allocator, "    pos = vec4(position.xyz, 1.0);\n");
        if (inline_mat) |m| {
            const mr = zm.matToArr(m);
            var line = try shader_helpers.vec4_to_buf("    vec4 c0 = vec4({d}, {d}, {d}, {d});\n", mr[0], mr[1], mr[2], mr[3]);
            try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
            line = try shader_helpers.vec4_to_buf("    vec4 c1 = vec4({d}, {d}, {d}, {d});\n", mr[4], mr[5], mr[6], mr[7]);
            try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
            line = try shader_helpers.vec4_to_buf("    vec4 c2 = vec4({d}, {d}, {d}, {d});\n", mr[8], mr[9], mr[10], mr[11]);
            try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
            line = try shader_helpers.vec4_to_buf("    vec4 c3 = vec4({d}, {d}, {d}, {d});\n", mr[12], mr[13], mr[14], mr[15]);
            try buf.appendSlice(allocator, std.mem.sliceTo(&line, 0));
            try buf.appendSlice(allocator, "    mat4 inline_transform = mat4(c0, c1, c2, c3);\n");
            try buf.appendSlice(allocator, "    pos = inline_transform * pos;\n");
        }
        if (cfg.has_uniform_mat) {
            try buf.appendSlice(allocator, "    pos = ");
            try buf.appendSlice(allocator, shader_constants.TransformMatName);
            try buf.appendSlice(allocator, " * pos;\n");
        }
        if (cfg.has_ubo) {
            try buf.appendSlice(allocator, "    pos = ");
            try buf.appendSlice(allocator, shader_constants.UBOMatName);
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
};
