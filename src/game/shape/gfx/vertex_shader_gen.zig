const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl");
const math = @import("../../math/math.zig");
const shader_constants = @import("shader_constants.zig");
const shader_helpers = @import("shader_helpers.zig");
const game = @import("../../game.zig");

pub const VertexShaderGen = struct {
    pub const vertexShaderConfig = struct {
        debug: bool = false,
        has_uniform_mat: bool = false,
        has_ubo: bool = false,
        has_texture_coords: bool = false,
        animation_block_index: ?gl.Uint = null,
        has_normals: bool = false,
        scale: ?math.vecs.Vflx4 = null,
        rotation: ?math.vecs.Vflx4 = null,
        translation: ?math.vecs.Vflx4 = null,
    };

    // genVertexShader - call ower owns the returned slice and must free it
    pub fn genVertexShader(cfg: vertexShaderConfig) ![:0]const u8 {
        var r = runner.init(game.state.allocator, cfg);
        defer r.deinit();
        return try r.run();
    }

    const runner = struct {
        allocator: std.mem.Allocator,
        buf: std.ArrayListUnmanaged(u8),
        cfg: vertexShaderConfig,

        fn init(
            allocator: std.mem.Allocator,
            cfg: vertexShaderConfig,
        ) runner {
            return .{
                .allocator = allocator,
                .cfg = cfg,
                .buf = std.ArrayListUnmanaged(u8){},
            };
        }

        fn deinit(r: *runner) void {
            defer r.buf.deinit(r.allocator);
        }

        fn run(r: *runner) ![:0]const u8 {
            try r.buf.appendSlice(r.allocator, "#version 450 core\n");
            try r.gen_attribute_vars();
            try r.gen_out_vars();
            try r.gen_uniforms();
            try r.gen_ubo();
            try r.gen_animation_block();
            try r.gen_main();
            const ownedSentinelSlice: [:0]const u8 = try r.buf.toOwnedSliceSentinel(r.allocator, 0);
            if (r.cfg.debug) std.debug.print("generated vertex shader: \n {s}\n", .{ownedSentinelSlice});
            return ownedSentinelSlice;
        }

        fn gen_attribute_vars(r: *runner) !void {
            var location: u8 = 0;
            var line = try shader_helpers.attribute_location(location, "position", .vec3);
            try r.buf.appendSlice(r.allocator, std.mem.sliceTo(&line, 0));
            location += 1;
            if (r.cfg.has_texture_coords) {
                line = try shader_helpers.attribute_location(location, "eTexCoord", .vec2);
                try r.buf.appendSlice(r.allocator, std.mem.sliceTo(&line, 0));
                location += 1;
            }
            if (r.cfg.has_normals) {
                line = try shader_helpers.attribute_location(location, "normal", .vec3);
                try r.buf.appendSlice(r.allocator, std.mem.sliceTo(&line, 0));
                location += 1;
            }
        }

        fn gen_out_vars(r: *runner) !void {
            try r.buf.appendSlice(r.allocator, "\n");
            if (r.cfg.has_texture_coords) {
                try r.buf.appendSlice(r.allocator, "\nout vec2 TexCoord;\n");
            }
            if (r.cfg.has_normals) {
                try r.buf.appendSlice(r.allocator, "\nflat out vec3 fragNormal;\n");
            }
        }

        fn gen_uniforms(r: *runner) !void {
            if (r.cfg.has_uniform_mat) {
                try r.buf.appendSlice(r.allocator, "\nuniform mat4 ");
                try r.buf.appendSlice(r.allocator, shader_constants.TransformMatName);
                try r.buf.appendSlice(r.allocator, ";\n\n");
            }
        }

        fn gen_ubo(r: *runner) !void {
            if (r.cfg.has_ubo) {
                try r.buf.appendSlice(r.allocator, "\nlayout(std140) uniform ");
                try r.buf.appendSlice(r.allocator, shader_constants.UBOName);
                try r.buf.appendSlice(r.allocator, " {\n    mat4 ");
                try r.buf.appendSlice(r.allocator, shader_constants.UBOMatName);
                try r.buf.appendSlice(r.allocator, ";\n};\n\n");
            }
        }

        fn gen_animation_block(r: *runner) !void {
            if (r.cfg.animation_block_index) |bi| {
                try r.buf.appendSlice(r.allocator, "\n\nstruct key_frame {\n");
                try r.buf.appendSlice(r.allocator, "    vec4 scale;\n");
                try r.buf.appendSlice(r.allocator, "    vec4 rotation;\n");
                try r.buf.appendSlice(r.allocator, "    vec4 translation;\n");
                try r.buf.appendSlice(r.allocator, "};\n\n");
                try r.buf.appendSlice(r.allocator, "\n");
                var line = try shader_helpers.ssbo_binding(bi, shader_constants.AnimationBlockName);
                try r.buf.appendSlice(r.allocator, std.mem.sliceTo(&line, 0));
                try r.buf.appendSlice(r.allocator, "{\n");
                try r.buf.appendSlice(r.allocator, "    key_frame frames[];\n");
                try r.buf.appendSlice(r.allocator, "};\n\n");
            }
        }

        fn gen_inline_mat(r: *runner) !void {
            var inline_mat: ?zm.Mat = null;
            {
                var m = zm.identity();
                if (r.cfg.scale) |s| {
                    m = zm.mul(m, zm.scalingV(s.value));
                    inline_mat = m;
                }
                if (r.cfg.rotation) |_r| {
                    m = zm.mul(m, zm.quatToMat(_r.value));
                    inline_mat = m;
                }
                if (r.cfg.translation) |t| {
                    m = zm.mul(m, zm.translationV(t.value));
                    inline_mat = m;
                }
            }
            if (inline_mat) |m| {
                const mr = zm.matToArr(m);
                var line = try shader_helpers.vec4_to_buf("    vec4 c0 = vec4({d}, {d}, {d}, {d});\n", mr[0], mr[1], mr[2], mr[3]);
                try r.buf.appendSlice(r.allocator, std.mem.sliceTo(&line, 0));
                line = try shader_helpers.vec4_to_buf("    vec4 c1 = vec4({d}, {d}, {d}, {d});\n", mr[4], mr[5], mr[6], mr[7]);
                try r.buf.appendSlice(r.allocator, std.mem.sliceTo(&line, 0));
                line = try shader_helpers.vec4_to_buf("    vec4 c2 = vec4({d}, {d}, {d}, {d});\n", mr[8], mr[9], mr[10], mr[11]);
                try r.buf.appendSlice(r.allocator, std.mem.sliceTo(&line, 0));
                line = try shader_helpers.vec4_to_buf("    vec4 c3 = vec4({d}, {d}, {d}, {d});\n", mr[12], mr[13], mr[14], mr[15]);
                try r.buf.appendSlice(r.allocator, std.mem.sliceTo(&line, 0));
                try r.buf.appendSlice(r.allocator, "    mat4 inline_transform = mat4(c0, c1, c2, c3);\n");
                try r.buf.appendSlice(r.allocator, "    pos = inline_transform * pos;\n");
            }
        }

        fn gen_main(r: *runner) !void {
            try r.buf.appendSlice(r.allocator, "void main()\n");
            try r.buf.appendSlice(r.allocator, "{\n");
            try r.buf.appendSlice(r.allocator, "    vec4 pos;\n");
            try r.buf.appendSlice(r.allocator, "    pos = vec4(position.xyz, 1.0);\n");
            try r.gen_inline_mat();
            if (r.cfg.animation_block_index != null) {
                try r.buf.appendSlice(r.allocator, "    key_frame kf = frames[1];\n");
                try r.buf.appendSlice(r.allocator, "    vec4 kft0 = vec4(1, 0, 0, 0);\n");
                try r.buf.appendSlice(r.allocator, "    vec4 kft1 = vec4(0, 1, 0, 0);\n");
                try r.buf.appendSlice(r.allocator, "    vec4 kft2 = vec4(0, 0, 1, 0);\n");
                try r.buf.appendSlice(r.allocator, "    vec4 kft3 =  vec4(kf.translation.x, kf.translation.y, kf.translation.z, 1);\n");
                try r.buf.appendSlice(r.allocator, "    mat4 my_mat = mat4(kft0, kft1, kft2, kft3);\n");
                try r.buf.appendSlice(r.allocator, "    pos = my_mat * pos;\n");
            }
            if (r.cfg.has_uniform_mat) {
                try r.buf.appendSlice(r.allocator, "    pos = ");
                try r.buf.appendSlice(r.allocator, shader_constants.TransformMatName);
                try r.buf.appendSlice(r.allocator, " * pos;\n");
            }
            if (r.cfg.has_ubo) {
                try r.buf.appendSlice(r.allocator, "    pos = ");
                try r.buf.appendSlice(r.allocator, shader_constants.UBOMatName);
                try r.buf.appendSlice(r.allocator, " * pos;\n");
            }
            try r.buf.appendSlice(r.allocator, "    gl_Position = pos;\n");
            if (r.cfg.has_texture_coords) {
                try r.buf.appendSlice(r.allocator, "    TexCoord = eTexCoord;\n");
            }
            if (r.cfg.has_normals) {
                try r.buf.appendSlice(r.allocator, "    fragNormal = normal;\n");
            }
            try r.buf.appendSlice(r.allocator, "}\n");
        }
    };
};
