const std = @import("std");
const zm = @import("zmath");
const math = @import("../math/math.zig");
const game = @import("../game.zig");
const constants = @import("gfx_constants.zig");
const shader_helpers = @import("shader_helpers.zig");

pub const FragmentShaderGen = struct {
    pub const fragmentShaderConfig = struct {
        debug: bool = false,
        has_texture: bool = false,
        has_texture_coords: bool = false,
        has_normals: bool = false,
        color: ?@Vector(4, f32) = null,
        outline_color: ?@Vector(4, f32) = null,
        is_meshed: bool = false,
        has_block_data: bool = false,
        lighting_block_index: ?u32 = null,
    };

    // genFragmentShader - call ower owns the returned slice
    pub fn genFragmentShader(cfg: fragmentShaderConfig) ![:0]const u8 {
        var r = runner.init(game.state.allocator, cfg);
        defer r.deinit();
        return try r.run();
    }

    const runner = struct {
        allocator: std.mem.Allocator,
        buf: std.ArrayListUnmanaged(u8),
        cfg: fragmentShaderConfig,

        fn init(
            allocator: std.mem.Allocator,
            cfg: fragmentShaderConfig,
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
            r.a("out vec4 FragColor;\n");
            if (r.cfg.is_meshed) {
                r.a("\nin vec3 fragPos;\n");
                r.a("\nflat in float bl_surface_height;\n");
            }
            if (r.cfg.has_texture_coords) {
                r.a("\nin vec2 TexCoord;\n");
            }
            if (r.cfg.has_normals) {
                r.a("\nflat in vec3 fragNormal;\n");
            }
            if (r.cfg.outline_color != null) {
                r.a("\nin vec2 bl_edge;\n");
                r.a("\nin vec3 bl_baryc;\n");
            }
            if (r.cfg.is_meshed and r.cfg.has_block_data) {
                r.a("flat in float bl_block_index;\n");
                r.a("flat in float bl_num_blocks;\n");
                r.a("flat in uint bl_block_ambient;\n");
                r.a("flat in uint bl_block_lighting;\n");
            }
            if (r.cfg.has_texture) {
                r.a("\nuniform sampler2D texture1;\n\n");
            }
            if (r.cfg.lighting_block_index) |bi| {
                const line = try shader_helpers.ssbo_binding(
                    bi,
                    constants.LightingBlockName,
                );
                r.l(&line);
                r.a("\n{\n");
                r.a("    vec4 bl_ambient;\n");
                r.a("};\n\n");
            }
            r.a("\nvoid main()\n");
            r.a("{\n");
            // magenta to highlight shader without materials
            if (r.cfg.color) |c| {
                const line = try shader_helpers.vec4_to_buf("    vec4 Color = vec4({d}, {d}, {d}, {d});\n", c[0], c[1], c[2], c[3]);
                r.l(&line);
            } else {
                r.a("    vec4 Color = vec4(1.0, 0.0, 1.0, 1.0);\n");
            }
            if (r.cfg.has_texture) {
                r.a("    vec4 textColor;\n");
                if (r.cfg.is_meshed and r.cfg.has_normals) {
                    r.a(@embedFile("fragments/meshed_texture.fs.txt"));
                } else if (r.cfg.has_texture_coords) {
                    r.a("    textColor = texture(texture1, TexCoord);\n");
                } else {
                    r.a("    textColor = vec4(1.0, 0.0, 1.0, 1.0);\n");
                }
                r.a("    Color = mix(Color, textColor, textColor.a);\n");
            }
            if (r.cfg.outline_color) |c| {
                const line = try shader_helpers.vec4_to_buf("    vec4 bl_outline_c = vec4({d}, {d}, {d}, {d});\n", c[0], c[1], c[2], c[3]);
                r.l(&line);
                r.a(@embedFile("fragments/outline.fs.txt"));
            }
            if (r.cfg.lighting_block_index != null) {
                r.a("   Color = min(Color * bl_ambient, vec4(1.0));\n");
            }
            r.a("    if (Color.a < 0.5) {\n");
            r.a("        discard;\n");
            r.a("    }\n");
            r.a("    FragColor = Color;\n");
            r.a("}\n");
            const ownedSentinelSlice: [:0]const u8 = try r.buf.toOwnedSliceSentinel(r.allocator, 0);
            if (r.cfg.debug) std.debug.print("generated fragment shader: \n {s}\n", .{ownedSentinelSlice});
            return ownedSentinelSlice;
        }
    };
};
