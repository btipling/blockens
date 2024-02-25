const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const game_state = @import("../../state/game.zig");
const game = @import("../../game.zig");

pub const shadergen = @import("shadergen.zig");
pub const buffer_data = @import("buffer_data.zig");

pub const GfxErr = error{
    RenderError,
};

pub const Gfx = struct {
    pub fn initVAO() !gl.Uint {
        var VAO: gl.Uint = undefined;
        gl.genVertexArrays(1, &VAO);
        gl.bindVertexArray(VAO);
        return VAO;
    }

    pub fn initVBO() !gl.Uint {
        var VBO: gl.Uint = undefined;
        gl.genBuffers(1, &VBO);
        gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
        return VBO;
    }

    pub fn initEBO(indices: []const gl.Uint) !gl.Uint {
        var EBO: gl.Uint = undefined;
        gl.genBuffers(1, &EBO);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);

        const size = @as(isize, @intCast(indices.len * @sizeOf(gl.Uint)));
        const indicesptr: *const anyopaque = indices.ptr;
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, size, indicesptr, gl.STATIC_DRAW);
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
        return shaderProgram;
    }

    pub fn setUniformMat(name: []const u8, program: gl.Uint, m: zm.Mat) void {
        gl.useProgram(program);

        var ma: [16]gl.Float = [_]gl.Float{undefined} ** 16;
        zm.storeMat(&ma, m);

        const location = gl.getUniformLocation(program, @ptrCast(name));
        gl.uniformMatrix4fv(location, 1, gl.FALSE, &ma);
    }

    pub fn setUniformBufferObject(name: []const u8, program: gl.Uint, ubo: gl.Uint, buffer_binding_point: gl.Uint) void {
        const blockIndex: gl.Uint = gl.getUniformBlockIndex(program, @ptrCast(name));
        gl.uniformBlockBinding(program, blockIndex, buffer_binding_point);
        gl.bindBufferBase(gl.UNIFORM_BUFFER, buffer_binding_point, ubo);
    }

    pub fn initUniformBufferObject(data: zm.Mat) gl.Uint {
        var ubo: gl.Uint = undefined;
        gl.genBuffers(1, &ubo);
        gl.bindBuffer(gl.UNIFORM_BUFFER, ubo);

        var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
        zm.storeMat(&transform, data);

        const size = @as(isize, @intCast(transform.len * @sizeOf(gl.Float)));
        gl.bufferData(gl.UNIFORM_BUFFER, size, &transform, gl.DYNAMIC_DRAW);
        gl.bindBuffer(gl.UNIFORM_BUFFER, 0);
        return ubo;
    }

    pub fn updateUniformBufferObject(updated: zm.Mat, ubo: gl.Uint) void {
        gl.bindBuffer(gl.UNIFORM_BUFFER, ubo);
        var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
        zm.storeMat(&transform, updated);
        const size: isize = @intCast(transform.len * @sizeOf(gl.Float));
        gl.bufferSubData(gl.UNIFORM_BUFFER, 0, size, &transform);
        gl.bindBuffer(gl.UNIFORM_BUFFER, 0);
    }

    pub fn initAnimationShaderStorageBufferObject(
        block_binding_point: gl.Uint,
        data: []game_state.ElementsRendererConfig.AnimationKeyFrame,
    ) gl.Uint {
        // _ = data;
        const kf = struct {
            scale: [4]gl.Float,
            rotation: [4]gl.Float,
            translation: [4]gl.Float,
        };
        var ar = std.ArrayListUnmanaged(kf){};
        defer ar.deinit(game.state.allocator);
        for (data) |d| {
            ar.append(game.state.allocator, kf{
                .scale = d.scale,
                .rotation = d.rotation,
                .translation = d.translation,
            }) catch unreachable;
        }
        var ssbo: gl.Uint = undefined;
        gl.genBuffers(1, &ssbo);
        gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);

        const data_ptr: *const anyopaque = ar.items.ptr;

        const size = @as(isize, @intCast(ar.items.len * @sizeOf(kf)));
        gl.bufferData(gl.SHADER_STORAGE_BUFFER, size, data_ptr, gl.STATIC_DRAW);
        gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, block_binding_point, ssbo);
        gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, 0);
        return ssbo;
    }

    pub fn initTextureFromColors(texture_data: []const gl.Uint) gl.Uint {
        var texture: gl.Uint = undefined;
        gl.genTextures(1, &texture);
        gl.bindTexture(gl.TEXTURE_2D, texture);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        const width: gl.Int = 16;
        const height: gl.Int = @divFloor(@as(gl.Int, @intCast(texture_data.len)), width);
        const imageData: *const anyopaque = texture_data.ptr;
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, imageData);
        gl.generateMipmap(gl.TEXTURE_2D);
        return texture;
    }
};
