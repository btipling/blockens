const std = @import("std");
const gl = @import("zopengl");
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

        fn run(r: *runner) ![:0]const u8 {
            try r.buf.appendSlice(r.allocator, "#version 330 core\n");
            try r.buf.appendSlice(r.allocator, "out vec4 FragColor;\n");
            if (r.cfg.has_texture_coords) {
                try r.buf.appendSlice(r.allocator, "\nin vec2 TexCoord;\n");
            }
            if (r.cfg.has_normals) {
                try r.buf.appendSlice(r.allocator, "\nflat in vec3 fragNormal;\n");
            }
            if (r.cfg.has_texture) {
                try r.buf.appendSlice(r.allocator, "\nuniform sampler2D texture1;\n");
            }
            try r.buf.appendSlice(r.allocator, "\nvoid main()\n");
            try r.buf.appendSlice(r.allocator, "{\n");
            // magenta to highlight shader without materials
            if (r.cfg.color) |c| {
                const line = try shader_helpers.vec4_to_buf("    vec4 Color = vec4({d}, {d}, {d}, {d});\n", c.value[0], c.value[1], c.value[2], c.value[3]);
                try r.buf.appendSlice(r.allocator, std.mem.sliceTo(&line, 0));
            } else {
                try r.buf.appendSlice(r.allocator, "    vec4 Color = vec4(1.0, 0.0, 1.0, 1.0);\n");
            }
            if (r.cfg.has_texture) {
                try r.buf.appendSlice(r.allocator, "    vec4 textureColor = texture(texture1, TexCoord);\n");
                try r.buf.appendSlice(r.allocator, "    vec4 finalColor = mix(Color, textureColor, textureColor.a);\n");
                try r.buf.appendSlice(r.allocator, "    FragColor = finalColor;\n");
            } else {
                try r.buf.appendSlice(r.allocator, "    FragColor = Color;\n");
            }
            try r.buf.appendSlice(r.allocator, "}\n");
            const ownedSentinelSlice: [:0]const u8 = try r.buf.toOwnedSliceSentinel(r.allocator, 0);
            if (r.cfg.debug) std.debug.print("generated fragment shader: \n {s}\n", .{ownedSentinelSlice});
            return ownedSentinelSlice;
        }
    };
};
