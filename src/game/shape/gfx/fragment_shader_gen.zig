const std = @import("std");
const gl = @import("zopengl").bindings;
const zm = @import("zmath");
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");
const shader_helpers = @import("shader_helpers.zig");

pub const FragmentShaderGen = struct {
    pub const fragmentShaderConfig = struct {
        debug: bool = false,
        has_texture: bool = false,
        has_texture_coords: bool = false,
        has_normals: bool = false,
        color: ?math.vecs.Vflx4 = null,
        is_meshed: bool = false,
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

        fn run(r: *runner) ![:0]const u8 {
            r.a("#version 330 core\n");
            r.a("out vec4 FragColor;\n");
            if (r.cfg.has_texture_coords) {
                r.a("\nin vec2 TexCoord;\n");
            }
            if (r.cfg.has_normals) {
                r.a("\nflat in vec3 fragNormal;\n");
            }
            if (r.cfg.has_texture) {
                r.a("\nuniform sampler2D texture1;\n");
            }
            r.a("\nvoid main()\n");
            r.a("{\n");
            // magenta to highlight shader without materials
            if (r.cfg.color) |c| {
                const line = try shader_helpers.vec4_to_buf("    vec4 Color = vec4({d}, {d}, {d}, {d});\n", c.value[0], c.value[1], c.value[2], c.value[3]);
                r.a(std.mem.sliceTo(&line, 0));
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
