const std = @import("std");
const gl = @import("zopengl");

pub const EntityErr = error{Error};

pub const EntityConfig = struct {
    hasColor: bool,
    hasTexture: bool,
};

pub const Entity = struct {
    name: []const u8,
    vao: gl.Uint,
    uniforms: std.StringHashMap(gl.Uint),
    data: []const gl.Float,
    indices: []const gl.Uint,
    program: gl.Uint,
    config: EntityConfig,

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        data: []const gl.Float,
        indices: []const gl.Uint,
        vertexShaderSource: [:0]const u8,
        fragmentShaderSource: [:0]const u8,
        config: EntityConfig,
    ) !Entity {
        const uniforms = std.StringHashMap(gl.Uint).init(allocator);
        const vao = try initVAO(name);
        const vertexShader = try initVertexShader(vertexShaderSource, name);
        const fragmentShader = try initFragmentShader(fragmentShaderSource, name);
        try initVBO(name);
        try initEBO(name, indices);
        const program = try initProgram(name, &[_]gl.Uint{ vertexShader, fragmentShader });
        try initData(name, data, config);
        return Entity{
            .name = name,
            .vao = vao,
            .uniforms = uniforms,
            .data = data,
            .indices = indices,
            .program = program,
            .config = config,
        };
    }

    pub fn deinit(self: *Entity) void {
        gl.deleteVertexArrays(1, &self.vao);
        gl.deleteProgram(self.program);
        self.uniforms.deinit();
        return;
    }

    pub fn initVAO(msg: []const u8) !gl.Uint {
        var VAO: gl.Uint = undefined;
        gl.genVertexArrays(1, &VAO);
        gl.bindVertexArray(VAO);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("init vao error: {s} {d}\n", .{ msg, e });
            return EntityErr.Error;
        }
        return VAO;
    }

    pub fn initVBO(msg: []const u8) !void {
        var VBO: gl.Uint = undefined;
        gl.genBuffers(1, &VBO);
        gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("init vbo error: {s} {d}\n", .{ msg, e });
            return EntityErr.Error;
        }
        return;
    }

    pub fn initEBO(msg: []const u8, indices: []const gl.Uint) !void {
        var EBO: gl.Uint = undefined;
        gl.genBuffers(1, &EBO);
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("init ebo error: {s} {d}\n", .{ msg, e });
            return EntityErr.Error;
        }
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("bind ebo buff error: {s} {d}\n", .{ msg, e });
            return EntityErr.Error;
        }

        const size = @as(isize, @intCast(indices.len * @sizeOf(gl.Uint)));
        const indicesptr: *const anyopaque = indices.ptr;
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, size, indicesptr, gl.STATIC_DRAW);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} buffer data error: {d}\n", .{ msg, e });
            return EntityErr.Error;
        }
        return;
    }

    pub fn initVertexShader(vertexShaderSource: [:0]const u8, msg: []const u8) !gl.Uint {
        var buffer: [20]u8 = undefined;
        const shaderMsg = try std.fmt.bufPrint(&buffer, "{s}: VERTEX", .{msg});
        return initShader(shaderMsg, vertexShaderSource, gl.VERTEX_SHADER);
    }

    pub fn initFragmentShader(fragmentShaderSource: [:0]const u8, msg: []const u8) !gl.Uint {
        var buffer: [20]u8 = undefined;
        const shaderMsg = try std.fmt.bufPrint(&buffer, "{s}: FRAGMENT", .{msg});
        return initShader(shaderMsg, fragmentShaderSource, gl.FRAGMENT_SHADER);
    }

    pub fn initShader(name: []const u8, source: [:0]const u8, shaderType: c_uint) !gl.Uint {
        std.debug.print("{s} source: {s}\n", .{ name, source.ptr });

        const shader: gl.Uint = gl.createShader(shaderType);
        gl.shaderSource(shader, 1, &[_][*c]const u8{source.ptr}, null);
        gl.compileShader(shader);

        var success: gl.Int = 0;
        gl.getShaderiv(shader, gl.COMPILE_STATUS, &success);
        if (success == 0) {
            var infoLog: [512]u8 = undefined;
            var logSize: gl.Int = 0;
            gl.getShaderInfoLog(shader, 512, &logSize, &infoLog);
            const i: usize = @intCast(logSize);
            std.debug.print("ERROR::SHADER::{s}::COMPILATION_FAILED\n{s}\n", .{ name, infoLog[0..i] });
            return EntityErr.Error;
        }

        var infoLog: [512]u8 = undefined;
        var logSize: gl.Int = 0;
        gl.getShaderInfoLog(shader, 512, &logSize, &infoLog);
        const i: usize = @intCast(logSize);
        std.debug.print("INFO::SHADER::{s}::LINKING_SUCCESS\n{s}\n", .{ name, infoLog[0..i] });

        return shader;
    }

    pub fn initProgram(name: []const u8, shaders: []const gl.Uint) !gl.Uint {
        const shaderProgram: gl.Uint = gl.createProgram();
        for (shaders) |shader| {
            gl.attachShader(shaderProgram, shader);
        }
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} error: {d}\n", .{ name, e });
            return EntityErr.Error;
        }

        gl.linkProgram(shaderProgram);
        var success: gl.Int = 0;
        gl.getProgramiv(shaderProgram, gl.LINK_STATUS, &success);
        if (success == 0) {
            var infoLog: [512]u8 = undefined;
            var logSize: gl.Int = 0;
            gl.getProgramInfoLog(shaderProgram, 512, &logSize, &infoLog);
            const i: usize = @intCast(logSize);
            std.debug.print("ERROR::SHADER::{s}::PROGRAM::LINKING_FAILED\n{s}\n", .{ name, infoLog[0..i] });
            return EntityErr.Error;
        }
        var infoLog: [512]u8 = undefined;
        var logSize: gl.Int = 0;
        gl.getProgramInfoLog(shaderProgram, 512, &logSize, &infoLog);
        const i: usize = @intCast(logSize);
        std.debug.print("INFO::SHADER::{s}::PROGRAM::LINKING_SUCCESS {d}\n{s}\n", .{ name, i, infoLog[0..i] });

        for (shaders) |shader| {
            gl.deleteShader(shader);
        }

        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} error: {d}\n", .{ name, e });
            return EntityErr.Error;
        }
        std.debug.print("{s} program set up \n", .{name});
        return shaderProgram;
    }

    fn initData(name: []const u8, data: []const gl.Float, config: EntityConfig) !void {
        const size = @as(isize, @intCast(data.len * @sizeOf(gl.Float)));
        const dataptr: *const anyopaque = data.ptr;
        gl.bufferData(gl.ARRAY_BUFFER, size, dataptr, gl.STATIC_DRAW);
        var stride: gl.Int = 3;
        if (config.hasColor) {
            stride += 3;
        }
        var curArr: gl.Uint = 0;
        gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), null);
        gl.enableVertexAttribArray(curArr);
        curArr += 1;
        if (config.hasColor) {
            gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), @as(*anyopaque, @ptrFromInt(3 * @sizeOf(gl.Float))));
            gl.enableVertexAttribArray(curArr);
            curArr += 1;
        }
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} init data error: {d}\n", .{ name, e });
            return EntityErr.Error;
        }
    }

    pub fn draw(self: Entity) !void {
        gl.useProgram(self.program);
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("error: {d}\n", .{e});
            return EntityErr.Error;
        }
        gl.bindVertexArray(self.vao);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("error: {d}\n", .{e});
            return EntityErr.Error;
        }

        gl.drawElements(gl.TRIANGLES, @as(c_int, @intCast((self.indices.len))), gl.UNSIGNED_INT, null);
        if (e != gl.NO_ERROR) {
            std.debug.print("error: {d}\n", .{e});
            return EntityErr.Error;
        }
    }
};
