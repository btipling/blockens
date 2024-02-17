const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");

pub const shadergen = @import("shadergen.zig");

pub const GfxErr = error{
    RenderError,
};

pub const Gfx = struct {
    pub fn initVAO() !gl.Uint {
        var VAO: gl.Uint = undefined;
        gl.genVertexArrays(1, &VAO);
        gl.bindVertexArray(VAO);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("init vao error meshId: {d}\n", .{e});
            return GfxErr.RenderError;
        }
        return VAO;
    }

    pub fn initVBO() !gl.Uint {
        var VBO: gl.Uint = undefined;
        gl.genBuffers(1, &VBO);
        gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("init vbo error meshId {d}\n", .{e});
            return GfxErr.RenderError;
        }
        return VBO;
    }

    pub fn initEBO(indices: []const gl.Uint) !gl.Uint {
        var EBO: gl.Uint = undefined;
        gl.genBuffers(1, &EBO);
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("init ebo error meshId: {d}\n", .{e});
            return GfxErr.RenderError;
        }
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("bind ebo buff error meshId: {d}\n", .{e});
            return GfxErr.RenderError;
        }

        const size = @as(isize, @intCast(indices.len * @sizeOf(gl.Uint)));
        const indicesptr: *const anyopaque = indices.ptr;
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, size, indicesptr, gl.STATIC_DRAW);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("buffer data error meshId: {d}\n", .{e});
            return GfxErr.RenderError;
        }
        return EBO;
    }

    pub fn initVertexShader(vertexShaderSource: [:0]const u8) !gl.Uint {
        return initShader(vertexShaderSource, gl.VERTEX_SHADER);
    }

    pub fn initFragmentShader(fragmentShaderSource: [:0]const u8) !gl.Uint {
        return initShader(fragmentShaderSource, gl.FRAGMENT_SHADER);
    }

    pub fn initShader(source: [:0]const u8, shaderType: c_uint) !gl.Uint {
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
            std.debug.print("ERROR::SHADER::COMPILATION_FAILED\n{s}\n", .{infoLog[0..i]});
            return GfxErr.RenderError;
        }

        return shader;
    }

    pub fn initProgram(shaders: []const gl.Uint) !gl.Uint {
        const shaderProgram: gl.Uint = gl.createProgram();
        for (shaders) |shader| {
            gl.attachShader(shaderProgram, shader);
        }
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("initProgram error: {d}\n", .{e});
            return GfxErr.RenderError;
        }

        gl.linkProgram(shaderProgram);
        var success: gl.Int = 0;
        gl.getProgramiv(shaderProgram, gl.LINK_STATUS, &success);
        if (success == 0) {
            var infoLog: [512]u8 = undefined;
            var logSize: gl.Int = 0;
            gl.getProgramInfoLog(shaderProgram, 512, &logSize, &infoLog);
            const i: usize = @intCast(logSize);
            std.debug.print("ERROR::SHADER::PROGRAM::LINKING_FAILED\n{s}\n", .{infoLog[0..i]});
            return GfxErr.RenderError;
        }

        for (shaders) |shader| {
            gl.deleteShader(shader);
        }

        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("initProgram error: {d}\n", .{e});
            return GfxErr.RenderError;
        }
        return shaderProgram;
    }

    pub fn addVertexAttribute(comptime T: type, dataptr: ?*const anyopaque, len: gl.Int) !void {
        const size = len * @sizeOf(T);
        const stride = len * @sizeOf(T);
        gl.bufferData(gl.ARRAY_BUFFER, size, dataptr, gl.STATIC_DRAW);
        gl.vertexAttribPointer(0, len, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), null);
        gl.enableVertexAttribArray(0);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("addVertexAttribute init data error: {d}\n", .{e});
            return GfxErr.RenderError;
        }
    }

    pub fn setUniformMat(name: []const u8, program: gl.Uint, m: zm.Mat) !void {
        gl.useProgram(program);
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("setUniformMat {s} error: {d}\n", .{ name, e });
            return GfxErr.RenderError;
        }

        var ma: [16]gl.Float = [_]gl.Float{undefined} ** 16;
        zm.storeMat(&ma, m);

        const location = gl.getUniformLocation(program, @ptrCast(name));
        gl.uniformMatrix4fv(location, 1, gl.FALSE, &ma);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("setUniformMat {s} error: {d}\n", .{ name, e });
            return GfxErr.RenderError;
        }
    }
};
