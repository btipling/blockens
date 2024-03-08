const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const math = @import("../../math/math.zig");
const shader_constants = @import("shader_constants.zig");
const shader_helpers = @import("shader_helpers.zig");
const game = @import("../../game.zig");

pub const MeshTransforms = struct {
    scale: ?@Vector(4, gl.Float),
    rotation: ?@Vector(4, gl.Float),
    translation: ?@Vector(4, gl.Float),
};

pub const VertexShaderGen = struct {
    pub const vertexShaderConfig = struct {
        debug: bool = false,
        has_uniform_mat: bool = false,
        has_ubo: bool = false,
        has_texture_coords: bool = false,
        animation_block_index: ?gl.Uint = null,
        animation_id: ?gl.Uint = 0,
        num_animation_frames: gl.Uint = 0,
        has_normals: bool = false,
        scale: ?@Vector(4, gl.Float) = null,
        rotation: ?@Vector(4, gl.Float) = null,
        translation: ?@Vector(4, gl.Float) = null,
        is_instanced: bool = false,
        is_meshed: bool = false,
        mesh_transforms: ?[]MeshTransforms,
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
        location: u8 = 0,

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

        fn a(r: *runner, line: []const u8) void {
            r.buf.appendSlice(r.allocator, line) catch unreachable;
        }

        fn l(r: *runner, line: [:0]const u8) void {
            r.a(std.mem.sliceTo(line, 0));
        }

        fn run(r: *runner) ![:0]const u8 {
            r.a("#version 450 core\n");
            try r.gen_attribute_vars();
            try r.gen_instanced_vars();
            try r.gen_out_vars();
            try r.gen_mesh_transforms_decls();
            try r.gen_uniforms();
            try r.gen_ubo();
            try r.gen_animation_block();
            try r.gen_math();
            try r.gen_animation_functions();
            try r.gen_main();
            const ownedSentinelSlice: [:0]const u8 = try r.buf.toOwnedSliceSentinel(r.allocator, 0);
            if (r.cfg.debug) std.debug.print("generated vertex shader: \n {s}\n", .{ownedSentinelSlice});
            return ownedSentinelSlice;
        }

        fn gen_attribute_vars(r: *runner) !void {
            var line = try shader_helpers.attribute_location(r.location, "position", .vec3);
            r.l(&line);
            r.location += 1;
            if (r.cfg.has_texture_coords) {
                line = try shader_helpers.attribute_location(r.location, "eTexCoord", .vec2);
                r.l(&line);
                r.location += 1;
            }
            if (r.cfg.has_normals) {
                line = try shader_helpers.attribute_location(r.location, "normal", .vec3);
                r.l(&line);
                r.location += 1;
            }
        }

        fn gen_instanced_vars(r: *runner) !void {
            if (!r.cfg.is_instanced) return;
            var line = try shader_helpers.attribute_location(r.location, "attribTransform", .mat4);
            r.l(&line);
            r.location += 1;
        }

        fn gen_out_vars(r: *runner) !void {
            r.a("\n");
            if (r.cfg.has_texture_coords) {
                r.a("\nout vec2 TexCoord;\n");
            }
            if (r.cfg.is_meshed) {
                r.a("\nout vec3 fragPos;\n");
            }
            if (r.cfg.has_normals) {
                r.a("\nflat out vec3 fragNormal;\n");
            }
        }

        fn gen_uniforms(r: *runner) !void {
            if (r.cfg.has_uniform_mat) {
                r.a("\nuniform mat4 ");
                r.a(shader_constants.TransformMatName);
                r.a(";\n\n");
            }
        }

        fn gen_ubo(r: *runner) !void {
            if (r.cfg.has_ubo) {
                r.a("\nlayout(std140) uniform ");
                r.a(shader_constants.UBOName);
                r.a(" {\n    mat4 ");
                r.a(shader_constants.UBOMatName);
                r.a(";\n");
                r.a("    vec4 ");
                r.a(shader_constants.UBOAnimationDataName);
                r.a(";\n");
                r.a("    uint ");
                r.a(shader_constants.UBOGFXDataName);
                r.a("[4];\n");
                r.a("};\n\n");
            }
        }

        fn gen_animation_block(r: *runner) !void {
            var line = try shader_helpers.scalar(
                usize,
                "\nuint num_animation_frames = {d};\n",
                r.cfg.num_animation_frames,
            );
            r.l(&line);
            if (r.cfg.animation_block_index) |bi| {
                r.a("struct key_frame {\n");
                r.a("    vec4 data;\n");
                r.a("    vec4 scale;\n");
                r.a("    vec4 rotation;\n");
                r.a("    vec4 translation;\n");
                r.a("};\n\n");
                r.a("\n");
                line = try shader_helpers.ssbo_binding(bi, shader_constants.AnimationBlockName);
                r.l(&line);
                r.a("{\n");
                line = try shader_helpers.scalar(usize, "    key_frame frames[{d}];\n", r.cfg.num_animation_frames);
                r.l(&line);
                r.a("};\n\n");
            }
        }

        fn gen_mesh_transforms_decls(r: *runner) !void {
            if (r.cfg.mesh_transforms == null) return;
            r.a("\n\n");
            const mts = r.cfg.mesh_transforms.?;
            {
                const line = try shader_helpers.scalar(usize, "uint num_mesh_transforms = {d}u;\n", mts.len);
                r.l(&line);
            }
            {
                const line = try shader_helpers.scalar(usize, "mat4 mesh_transforms[{d}];\n", mts.len);
                r.l(&line);
            }
            r.a("\n");
        }

        fn gen_animation_frames(r: *runner) !void {
            if (r.cfg.animation_block_index == null) return;
            if (r.cfg.animation_id) |ai| {
                if (ai != 0) {
                    r.a("   bool isAnimationRunning = (");
                    r.a(shader_constants.UBOGFXDataName);
                    const line = try shader_helpers.scalar(usize, "[0] & 0x{X}u) != 0u;\n", ai);
                    r.l(&line);
                    r.a("   if(isAnimationRunning) {\n");
                }
            }
            r.a("    AnimationFrameIndices indices = get_frame_indices();\n");
            r.a("    key_frame kf = frames[indices.index1];\n");
            r.a("    key_frame sf = frames[indices.index2];\n");
            r.a("    vec4 traq = linear_interpolate(kf.translation, sf.translation, indices.t);\n");
            r.a("    vec4 kft0 = vec4(1, 0, 0, 0);\n");
            r.a("    vec4 kft1 = vec4(0, 1, 0, 0);\n");
            r.a("    vec4 kft2 = vec4(0, 0, 1, 0);\n");
            r.a("    vec4 kft3 =  vec4(traq.x, traq.y, traq.z, 1);\n");
            r.a("    mat4 trans = mat4(kft0, kft1, kft2, kft3);\n");
            r.a("    vec4 rotq = slerp(kf.rotation, sf.rotation, indices.t);\n");
            r.a("    mat4 rot = quat_to_mat(rotq);\n");

            r.a("    pos = scam * pos;\n");
            r.a("    pos = rot * pos;\n");
            r.a("    pos = trans * pos;\n");
            if (r.cfg.animation_id) |ai| {
                if (ai != 0) {
                    r.a("   }\n");
                }
            }
        }

        fn gen_mesh_transforms(r: *runner) !void {
            if (r.cfg.mesh_transforms == null) return;
            r.a("\n");
            const mts = r.cfg.mesh_transforms.?;
            for (mts, 0..) |mt, i| {
                var line = try shader_helpers.scalar(usize, "    mesh_transforms[{d}] = mat4(\n", i);
                r.l(&line);
                var m = zm.identity();
                if (mt.scale) |s| {
                    m = zm.mul(m, zm.scalingV(s));
                }
                if (mt.rotation) |_r| {
                    m = zm.mul(m, zm.quatToMat(_r));
                }
                if (mt.translation) |t| {
                    m = zm.mul(m, zm.translationV(t));
                }
                const mr = zm.matToArr(m);
                line = try shader_helpers.vec4_to_buf("         vec4({d}, {d}, {d}, {d}),\n", mr[0], mr[1], mr[2], mr[3]);
                r.l(&line);
                line = try shader_helpers.vec4_to_buf("         vec4({d}, {d}, {d}, {d}),\n", mr[4], mr[5], mr[6], mr[7]);
                r.l(&line);
                line = try shader_helpers.vec4_to_buf("         vec4({d}, {d}, {d}, {d}),\n", mr[8], mr[9], mr[10], mr[11]);
                r.l(&line);
                line = try shader_helpers.vec4_to_buf("         vec4({d}, {d}, {d}, {d})\n", mr[12], mr[13], mr[14], mr[15]);
                r.l(&line);
                r.a("    );\n");
            }
            for (0..mts.len) |i| {
                if (r.cfg.animation_block_index != null and i == 0) {
                    if (r.cfg.animation_id != null and r.cfg.animation_id != 0) {
                        r.a("   if(!isAnimationRunning) {\n");
                        var line = try shader_helpers.scalar(usize, "       pos = mesh_transforms[{d}] * pos;\n", i);
                        r.l(&line);
                        r.a("   }\n");
                    }
                    continue;
                }
                var line = try shader_helpers.scalar(usize, "    pos = mesh_transforms[{d}] * pos;\n", i);
                r.l(&line);
            }

            r.a("\n");
        }

        fn gen_inline_mat(r: *runner) !void {
            var inline_mat: ?zm.Mat = null;
            {
                var m = zm.identity();
                if (r.cfg.scale) |s| {
                    m = zm.mul(m, zm.scalingV(s));
                    inline_mat = m;
                }
                if (r.cfg.rotation) |_r| {
                    m = zm.mul(m, zm.quatToMat(_r));
                    inline_mat = m;
                }
                if (r.cfg.translation) |t| {
                    m = zm.mul(m, zm.translationV(t));
                    inline_mat = m;
                }
            }
            if (inline_mat) |m| {
                const mr = zm.matToArr(m);
                var line = try shader_helpers.vec4_to_buf("    vec4 c0 = vec4({d}, {d}, {d}, {d});\n", mr[0], mr[1], mr[2], mr[3]);
                r.l(&line);
                line = try shader_helpers.vec4_to_buf("    vec4 c1 = vec4({d}, {d}, {d}, {d});\n", mr[4], mr[5], mr[6], mr[7]);
                r.l(&line);
                line = try shader_helpers.vec4_to_buf("    vec4 c2 = vec4({d}, {d}, {d}, {d});\n", mr[8], mr[9], mr[10], mr[11]);
                r.l(&line);
                line = try shader_helpers.vec4_to_buf("    vec4 c3 = vec4({d}, {d}, {d}, {d});\n", mr[12], mr[13], mr[14], mr[15]);
                r.l(&line);
                r.a("    mat4 inline_transform = mat4(c0, c1, c2, c3);\n");
                r.a("    pos = inline_transform * pos;\n");
            }
        }

        fn gen_instance_mat(r: *runner) !void {
            if (!r.cfg.is_instanced) return;
            r.a("    pos = attribTransform * pos;\n");
        }

        fn gen_main(r: *runner) !void {
            r.a("void main()\n");
            r.a("{\n");
            r.a("    vec4 pos;\n");
            r.a("    pos = vec4(position.xyz, 1.0);\n");
            var m = zm.identity();
            if (r.cfg.mesh_transforms) |mts| {
                const mt = mts[0];
                if (mt.scale) |s| {
                    m = zm.mul(m, zm.scalingV(s));
                }
            }
            const mr = zm.matToArr(m);
            var line = try shader_helpers.vec4_to_buf("    vec4 sc0 = vec4({d}, {d}, {d}, {d});\n", mr[0], mr[1], mr[2], mr[3]);
            r.l(&line);
            line = try shader_helpers.vec4_to_buf("    vec4 sc1 = vec4({d}, {d}, {d}, {d});\n", mr[4], mr[5], mr[6], mr[7]);
            r.l(&line);
            line = try shader_helpers.vec4_to_buf("    vec4 sc2 = vec4({d}, {d}, {d}, {d});\n", mr[8], mr[9], mr[10], mr[11]);
            r.l(&line);
            line = try shader_helpers.vec4_to_buf("    vec4 sc3 = vec4({d}, {d}, {d}, {d});\n", mr[12], mr[13], mr[14], mr[15]);
            r.l(&line);
            r.a("    mat4 scam = mat4(sc0, sc1, sc2, sc3);\n");
            try r.gen_instance_mat();
            try r.gen_inline_mat();
            try r.gen_animation_frames();
            try r.gen_mesh_transforms();
            if (r.cfg.has_uniform_mat) {
                r.a("    pos = ");
                r.a(shader_constants.TransformMatName);
                r.a(" * pos;\n");
            }
            if (r.cfg.has_ubo) {
                r.a("    pos = ");
                r.a(shader_constants.UBOMatName);
                r.a(" * pos;\n");
            }
            r.a("    gl_Position = pos;\n");
            if (r.cfg.has_texture_coords) {
                r.a("    TexCoord = eTexCoord;\n");
            }
            if (r.cfg.is_meshed) {
                r.a("    fragPos = position;\n");
            }
            if (r.cfg.has_normals) {
                r.a("    fragNormal = normal;\n");
            }
            r.a("}\n");
        }

        fn gen_math(r: *runner) !void {
            if (r.cfg.animation_block_index != null) {
                r.a("\n");
                r.a(@embedFile("fragments/q_to_mat.vs.txt"));
                r.a("\n\n");
                r.a(@embedFile("fragments/slerp.vs.txt"));
                r.a("\n\n");
                r.a(@embedFile("fragments/linear_interp.vs.txt"));
                r.a("\n\n");
            }
        }

        fn gen_animation_functions(r: *runner) !void {
            if (r.cfg.animation_block_index != null) {
                r.a("\n");
                r.a(@embedFile("fragments/frame_from_time.vs.txt"));
                r.a("\n\n");
            }
        }
    };
};
