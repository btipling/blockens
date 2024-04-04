const std = @import("std");
const zm = @import("zmath");
const math = @import("../math/math.zig");
const constants = @import("gfx_constants.zig");
const shader_helpers = @import("shader_helpers.zig");
const game = @import("../game.zig");
const gfx = @import("gfx.zig");

pub const MeshTransforms = struct {
    scale: ?@Vector(4, f32),
    rotation: ?@Vector(4, f32),
    translation: ?@Vector(4, f32),
};

pub const VertexShaderGen = struct {
    pub const vertexShaderConfig = struct {
        debug: bool = false,
        has_uniform_mat: bool = false,
        has_ubo: bool = false,
        has_texture_coords: bool = false,
        animation_block_index: ?u32,
        animation: ?*gfx.Animation,
        has_normals: bool = false,
        has_edges: bool = false,
        has_block_data: bool = false,
        has_attr_translation: bool = false,
        scale: ?@Vector(4, f32) = null,
        rotation: ?@Vector(4, f32) = null,
        translation: ?@Vector(4, f32) = null,
        is_instanced: bool = false,
        is_multi_draw: bool = false,
        is_meshed: bool = false,
        mesh_transforms: ?[]MeshTransforms,
        num_animation_frames: usize,
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
            if (r.cfg.has_edges) {
                line = try shader_helpers.attribute_location(r.location, "bl_edge_coord", .vec2);
                r.l(&line);
                r.location += 1;
                line = try shader_helpers.attribute_location(r.location, "bl_barycentric_coord", .vec3);
                r.l(&line);
                r.location += 1;
            }
            if (r.cfg.has_block_data) {
                line = try shader_helpers.attribute_location(r.location, "block_data", .vec2);
                r.l(&line);
                r.location += 1;
            }
            if (r.cfg.has_attr_translation) {
                line = try shader_helpers.attribute_location(r.location, "bl_attr_tr", .vec4);
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
                r.a("out vec2 TexCoord;\n");
            }
            if (r.cfg.is_meshed) {
                r.a("out vec3 fragPos;\n");
                r.a("flat out highp float bl_surface_height;\n");
            }
            if (r.cfg.has_normals) {
                r.a("flat out vec3 fragNormal;\n");
            }
            if (r.cfg.has_edges) {
                r.a("out vec2 bl_edge;\n");
                r.a("out vec3 bl_baryc;\n");
            }

            if (r.cfg.has_block_data) {
                r.a("flat out float bl_block_index;\n");
            }
        }

        fn gen_uniforms(r: *runner) !void {
            if (r.cfg.has_uniform_mat) {
                r.a("\nuniform mat4 ");
                r.a(constants.TransformMatName);
                r.a(";\n\n");
            }
        }

        fn gen_ubo(r: *runner) !void {
            if (r.cfg.has_ubo) {
                r.a("\nlayout(std140) uniform ");
                r.a(constants.UBOName);
                r.a(" {\n    mat4 ");
                r.a(constants.UBOMatName);
                r.a(";\n");
                r.a("    vec4 ");
                r.a(constants.UBOShaderDataName);
                r.a(";\n");
                r.a("    uint ");
                r.a(constants.UBOGFXDataName);
                r.a("[4];\n");
                r.a("};\n\n");
            }
        }

        fn gen_animation_block(r: *runner) !void {
            const animation = r.cfg.animation orelse return;
            const kf = animation.keyframes orelse return;
            var line = try shader_helpers.scalar(
                usize,
                // TODO: num_animation_frames is hard coded to one animation per mesh, which is wrong
                "\nuint num_animation_frames = {d};\n",
                kf.len,
            );
            r.l(&line);
            line = try shader_helpers.scalar(
                usize,
                // TODO: num_animation_frames is hard coded to one animation per mesh, which is wrong
                "\nuint bl_ani_offset = {d};\n",
                animation.animation_offset,
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
                line = try shader_helpers.ssbo_binding(bi, constants.AnimationBlockName);
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
            const animation = r.cfg.animation orelse return;
            const ai = animation.animation_id;
            if (ai != 0) {
                r.a("   bool isAnimationRunning = (");
                r.a(constants.UBOGFXDataName);
                const line = try shader_helpers.scalar(usize, "[0] & 0x{X}u) != 0u;\n", ai);
                r.l(&line);
                r.a("   if(isAnimationRunning) {\n");
            }
            r.a("    AnimationFrameIndices indices = get_frame_indices();\n");
            r.a("    key_frame kf = frames[bl_ani_offset + indices.index1];\n");
            r.a("    key_frame sf = frames[bl_ani_offset + indices.index2];\n");
            r.a("    vec4 traq = linear_interpolate(kf.translation, sf.translation, indices.t);\n");
            r.a("    vec4 kft0 = vec4(1, 0, 0, 0);\n");
            r.a("    vec4 kft1 = vec4(0, 1, 0, 0);\n");
            r.a("    vec4 kft2 = vec4(0, 0, 1, 0);\n");
            r.a("    vec4 kft3 =  vec4(traq.x, traq.y, traq.z, 1);\n");
            r.a("    mat4 bl_trans = mat4(kft0, kft1, kft2, kft3);\n");
            r.a("    vec4 rotq = slerp(kf.rotation, sf.rotation, indices.t);\n");
            r.a("    mat4 rot = quat_to_mat(rotq);\n");

            if (r.cfg.mesh_transforms != null) r.a("    pos = scam * pos;\n");
            r.a("    pos = rot * pos;\n");
            r.a("    pos = bl_trans * pos;\n");
            if (ai != 0) {
                r.a("   }\n");
            }
        }

        fn gen_attr_translation(r: *runner) !void {
            if (!r.cfg.has_attr_translation) return;
            r.a("    vec4 bl_atrt0 = vec4(1, 0, 0, 0);\n");
            r.a("    vec4 bl_atrt1 = vec4(0, 1, 0, 0);\n");
            r.a("    vec4 bl_atrt2 = vec4(0, 0, 1, 0);\n");
            r.a("    vec4 bl_atrt3 =  vec4(bl_attr_tr.x, bl_attr_tr.y, bl_attr_tr.z, 1);\n");
            r.a("    mat4 bl_attr_trm = mat4(bl_atrt0, bl_atrt1, bl_atrt2, bl_atrt3);\n");
            r.a("    pos = bl_attr_trm * pos;\n");
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
                    const animation = r.cfg.animation orelse continue;
                    const ai = animation.animation_id;
                    if (ai != 0) {
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

        fn gen_inline_mesh_transforms(r: *runner) !void {
            if (r.cfg.mesh_transforms == null) return;
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
        }

        fn gen_main(r: *runner) !void {
            r.a("void main()\n");
            r.a("{\n");
            r.a("    vec4 pos;\n");
            r.a("    pos = vec4(position.xyz, 1.0);\n");
            try r.gen_inline_mesh_transforms();
            try r.gen_attr_translation();
            try r.gen_instance_mat();
            try r.gen_inline_mat();
            try r.gen_animation_frames();
            try r.gen_mesh_transforms();
            if (r.cfg.has_uniform_mat) {
                r.a("    pos = ");
                r.a(constants.TransformMatName);
                r.a(" * pos;\n");
            }
            if (r.cfg.has_ubo) {
                r.a("    pos = ");
                r.a(constants.UBOMatName);
                r.a(" * pos;\n");
            }
            r.a("    gl_Position = pos;\n");
            if (r.cfg.has_texture_coords) {
                r.a("    TexCoord = eTexCoord;\n");
            }
            if (r.cfg.has_edges) {
                r.a("    bl_edge = bl_edge_coord;\n");
                r.a("    bl_baryc = bl_barycentric_coord;\n");
            }
            if (r.cfg.is_meshed) {
                r.a("    bl_surface_height = ");
                r.a(constants.UBOShaderDataName);
                r.a("[1];\n");
                r.a("    fragPos = position;\n");
                r.a("    fragPos = vec3(fragPos.x + 0.5, fragPos.y + 0.5, fragPos.z + 0.5);");
                if (r.cfg.has_block_data) {
                    r.a("    bl_block_index = block_data[0];\n");
                }
            }
            if (r.cfg.has_normals) {
                r.a("    fragNormal = normal;\n");
            }

            r.a("}\n");
        }

        fn gen_math(r: *runner) !void {
            if (r.cfg.animation != null) {
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
            if (r.cfg.animation != null) {
                r.a("\n");
                r.a(@embedFile("fragments/frame_from_time.vs.txt"));
                r.a("\n\n");
            }
        }
    };
};
