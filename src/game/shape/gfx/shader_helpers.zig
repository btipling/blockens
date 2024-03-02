const std = @import("std");
const gl = @import("zopengl").bindings;

pub const varType = enum {
    vec2,
    vec3,
    vec4,
    mat4,
};

pub fn attribute_location(
    loc: u8,
    comptime name: []const u8,
    var_type: varType,
) ![250:0]u8 {
    var buffer: [250:0]u8 = [_:0]u8{0} ** 250;
    const var_type_name: []const u8 = switch (var_type) {
        .vec2 => "vec2",
        .vec3 => "vec3",
        .vec4 => "vec4",
        .mat4 => "mat4",
    };
    _ = try std.fmt.bufPrint(&buffer, "layout (location = {d}) in {s} {s};\n", .{ loc, var_type_name, name });
    return buffer;
}

pub fn ssbo_binding(
    binding_point: gl.Uint,
    comptime name: []const u8,
) ![250:0]u8 {
    var buffer: [250:0]u8 = [_:0]u8{0} ** 250;
    _ = try std.fmt.bufPrint(&buffer, "layout (std430, binding = {d}) buffer {s} ", .{ binding_point, name });
    return buffer;
}

pub fn vec4_to_buf(
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
