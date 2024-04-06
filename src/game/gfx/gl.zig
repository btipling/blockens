const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const zstbi = @import("zstbi");
const gfx = @import("gfx.zig");
const game = @import("../game.zig");
const buffer_data = @import("buffer_data.zig");

pub var atlas_texture: ?u32 = null;

pub const GlErr = error{
    RenderError,
};

pub const Gl = struct {
    const Self = @This();
    var _gl = Self{};

    multi_draw_frag: u32 = 0,
    multi_draw_ver: u32 = 0,

    pub fn initVAO() !u32 {
        var VAO: u32 = undefined;
        gl.genVertexArrays(1, &VAO);
        gl.bindVertexArray(VAO);
        return VAO;
    }

    pub fn initVBO() !u32 {
        var VBO: u32 = undefined;
        gl.genBuffers(1, &VBO);
        gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
        return VBO;
    }

    pub fn initEBO(indices: []const u32) !u32 {
        var EBO: u32 = undefined;
        gl.genBuffers(1, &EBO);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);

        const size = @as(isize, @intCast(indices.len * @sizeOf(u32)));
        const indicesptr: *const anyopaque = indices.ptr;
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, size, indicesptr, gl.STATIC_DRAW);
        return EBO;
    }

    pub fn initVertexShader(vertexShaderSource: ?[:0]const u8) !u32 {
        const vs = vertexShaderSource orelse std.debug.panic("expected a vertex shader\n", .{});
        return initShader(vs, gl.VERTEX_SHADER);
    }

    pub fn initFragmentShader(fragmentShaderSource: ?[:0]const u8) !u32 {
        const fs = fragmentShaderSource orelse std.debug.panic("expected a vertex shader\n", .{});
        return initShader(fs, gl.FRAGMENT_SHADER);
    }

    pub fn hasMultiDrawShaders() bool {
        return _gl.multi_draw_frag != 0 and _gl.multi_draw_ver != 0;
    }

    pub fn initMultiDrawVertexShader(vertexShaderSource: ?[:0]const u8) !u32 {
        if (_gl.multi_draw_ver != 0) return _gl.multi_draw_ver;
        _gl.multi_draw_ver = try initVertexShader(vertexShaderSource);
        std.debug.print("creating new vertex multidraw shader {}\n", .{_gl.multi_draw_ver});
        return _gl.multi_draw_ver;
    }

    pub fn initMultiDrawFragmentShader(fragmentShaderSource: ?[:0]const u8) !u32 {
        if (_gl.multi_draw_frag != 0) return _gl.multi_draw_frag;
        _gl.multi_draw_frag = try initFragmentShader(fragmentShaderSource);
        std.debug.print("creating new fragment multidraw shader {}\n", .{_gl.multi_draw_frag});
        return _gl.multi_draw_frag;
    }

    pub fn initShader(source: [:0]const u8, shaderType: c_uint) !u32 {
        const shader: u32 = gl.createShader(shaderType);
        gl.shaderSource(shader, 1, &[_][*c]const u8{source.ptr}, null);
        gl.compileShader(shader);

        var success: i32 = 0;
        gl.getShaderiv(shader, gl.COMPILE_STATUS, &success);
        if (success == 0) {
            var infoLog: [512]u8 = undefined;
            var logSize: i32 = 0;
            gl.getShaderInfoLog(shader, 512, &logSize, &infoLog);
            const i: usize = @intCast(logSize);
            std.debug.print("ERROR::SHADER::COMPILATION_FAILED\n{s}\n", .{infoLog[0..i]});
            return GlErr.RenderError;
        }

        return shader;
    }

    pub fn initProgram(shaders: []const u32) !u32 {
        const shaderProgram: u32 = gl.createProgram();
        for (shaders) |shader| {
            gl.attachShader(shaderProgram, shader);
        }

        gl.linkProgram(shaderProgram);
        var success: i32 = 0;
        gl.getProgramiv(shaderProgram, gl.LINK_STATUS, &success);
        if (success == 0) {
            var infoLog: [512]u8 = undefined;
            var logSize: i32 = 0;
            gl.getProgramInfoLog(shaderProgram, 512, &logSize, &infoLog);
            const i: usize = @intCast(logSize);
            std.debug.print("ERROR::SHADER::PROGRAM::LINKING_FAILED\n{s}\n", .{infoLog[0..i]});
            return GlErr.RenderError;
        }

        for (shaders) |shader| {
            gl.deleteShader(shader);
        }
        return shaderProgram;
    }

    pub fn setUniformMat(name: []const u8, program: u32, m: zm.Mat) void {
        gl.useProgram(program);

        var ma: [16]f32 = [_]f32{undefined} ** 16;
        zm.storeMat(&ma, m);

        const location = gl.getUniformLocation(program, @ptrCast(name));
        gl.uniformMatrix4fv(location, 1, gl.FALSE, &ma);
    }

    pub fn setUniformBufferObject(name: []const u8, program: u32, ubo: u32, buffer_binding_point: u32) void {
        const blockIndex: u32 = gl.getUniformBlockIndex(program, @ptrCast(name));
        gl.uniformBlockBinding(program, blockIndex, buffer_binding_point);
        gl.bindBufferBase(gl.UNIFORM_BUFFER, buffer_binding_point, ubo);
    }

    pub fn initUniformBufferObject(data: zm.Mat) u32 {
        var ubo: u32 = undefined;
        gl.genBuffers(1, &ubo);
        gl.bindBuffer(gl.UNIFORM_BUFFER, ubo);
        const uboStruct = struct {
            transform: [16]f32 = [_]f32{undefined} ** 16,
            shader_data: [4]f32 = [_]f32{0} ** 4,
            gfx_data: [4]u32 = [_]u32{0} ** 4,
        };
        var ubo_data = uboStruct{};
        zm.storeMat(&ubo_data.transform, data);
        const size: isize = @intCast(@sizeOf(uboStruct));
        gl.bufferData(gl.UNIFORM_BUFFER, size, &ubo_data, gl.DYNAMIC_DRAW);
        gl.bindBuffer(gl.UNIFORM_BUFFER, 0);
        return ubo;
    }

    pub fn updateInstanceData(program: u32, vao: u32, vbo: u32, data: []f32) void {
        gl.useProgram(program);
        const size = @as(isize, @intCast(data.len * @sizeOf(f32)));
        const dataptr: *const anyopaque = data.ptr;
        gl.bindVertexArray(vao);
        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
        gl.bufferData(gl.ARRAY_BUFFER, size, dataptr, gl.STATIC_DRAW);
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
        gl.bindVertexArray(0);
        return;
    }

    pub fn updateUniformBufferObject(
        updated: zm.Mat,
        time: f32,
        animations_running: u32,
        num_blocks: usize,
        ubo: u32,
    ) void {
        gl.bindBuffer(gl.UNIFORM_BUFFER, ubo);
        const uboStruct = struct {
            transform: [16]f32 = [_]f32{undefined} ** 16,
            shader_data: [4]f32 = [_]f32{0} ** 4,
            gfx_data: [4]u32 = [_]u32{0} ** 4,
        };
        var ubo_data = uboStruct{};
        zm.storeMat(&ubo_data.transform, updated);
        ubo_data.shader_data[0] = time;
        ubo_data.shader_data[1] = 0.333 / @as(f32, @floatFromInt(num_blocks)); // texture.s surface height
        ubo_data.gfx_data[0] = animations_running;

        const size: isize = @intCast(@sizeOf(uboStruct));
        gl.bufferSubData(gl.UNIFORM_BUFFER, 0, size, &ubo_data);
        gl.bindBuffer(gl.UNIFORM_BUFFER, 0);
    }

    const animationKeyFrame = struct {
        data: [4]f32,
        scale: [4]f32,
        rotation: [4]f32,
        translation: [4]f32,
    };

    pub fn initAnimationShaderStorageBufferObject(
        block_binding_point: u32,
        data: []gfx.Animation.AnimationKeyFrame,
    ) u32 {
        var ar = std.ArrayListUnmanaged(animationKeyFrame){};
        defer ar.deinit(game.state.allocator);
        for (data) |d| {
            ar.append(game.state.allocator, animationKeyFrame{
                .data = [4]f32{ d.frame, 0, 0, 0 },
                .scale = d.scale,
                .rotation = d.rotation,
                .translation = d.translation,
            }) catch unreachable;
        }
        var ssbo: u32 = undefined;
        gl.genBuffers(1, &ssbo);
        gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);

        const data_ptr: *const anyopaque = ar.items.ptr;
        const struct_size = @sizeOf(animationKeyFrame);
        const size = @as(isize, @intCast(ar.items.len * struct_size));
        gl.bufferData(gl.SHADER_STORAGE_BUFFER, size, data_ptr, gl.DYNAMIC_DRAW);
        gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, block_binding_point, ssbo);
        gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, 0);
        return ssbo;
    }

    pub fn resizeAnimationShaderStorageBufferObject(ssbo: u32, num_frames: usize) void {
        const struct_size = @sizeOf(animationKeyFrame);
        const size = @as(isize, @intCast(num_frames * struct_size));
        const empty_frame: animationKeyFrame = .{
            .data = std.mem.zeroes([4]f32),
            .scale = std.mem.zeroes([4]f32),
            .rotation = std.mem.zeroes([4]f32),
            .translation = std.mem.zeroes([4]f32),
        };
        gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);
        gl.bufferData(gl.SHADER_STORAGE_BUFFER, size, &empty_frame, gl.DYNAMIC_DRAW);
    }

    pub fn addAnimationShaderStorageBufferData(
        ssbo: u32,
        offset: usize,
        data: []gfx.Animation.AnimationKeyFrame,
    ) void {
        var ar = std.ArrayListUnmanaged(animationKeyFrame){};
        defer ar.deinit(game.state.allocator);
        for (data) |d| {
            ar.append(game.state.allocator, animationKeyFrame{
                .data = [4]f32{ d.frame, 0, 0, 0 },
                .scale = d.scale,
                .rotation = d.rotation,
                .translation = d.translation,
            }) catch unreachable;
        }
        gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);

        const data_ptr: *const anyopaque = ar.items.ptr;

        const struct_size = @sizeOf(animationKeyFrame);
        const size: isize = @intCast(ar.items.len * struct_size);
        const buffer_offset: isize = @intCast(offset * struct_size);
        gl.bufferSubData(gl.SHADER_STORAGE_BUFFER, buffer_offset, size, data_ptr);
    }

    pub fn initTextureFromColors(texture_data: []const u32) u32 {
        var texture: u32 = undefined;
        gl.genTextures(1, &texture);
        gl.bindTexture(gl.TEXTURE_2D, texture);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        const width: i32 = 16;
        const height: i32 = @divFloor(@as(i32, @intCast(texture_data.len)), width);
        const imageData: *const anyopaque = texture_data.ptr;
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, imageData);
        gl.generateMipmap(gl.TEXTURE_2D);
        return texture;
    }

    pub fn initTextureAtlasFromColors(texture_data: []const u32) u32 {
        if (atlas_texture) |t| {
            gl.bindTexture(gl.TEXTURE_2D, t);
            return t;
        }
        var texture: u32 = undefined;
        gl.genTextures(1, &texture);
        gl.bindTexture(gl.TEXTURE_2D, texture);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        const width: i32 = 16;
        const height: i32 = @divFloor(@as(i32, @intCast(texture_data.len)), width);
        const imageData: *const anyopaque = texture_data.ptr;
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, imageData);
        gl.generateMipmap(gl.TEXTURE_2D);
        atlas_texture = texture;
        return texture;
    }

    pub fn initTextureFromImage(img: []u8) !u32 {
        var texture: u32 = undefined;
        gl.genTextures(1, &texture);
        gl.bindTexture(gl.TEXTURE_2D, texture);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        var image = try zstbi.Image.loadFromMemory(img, 4);
        defer image.deinit();

        const width: i32 = @as(i32, @intCast(image.width));
        const height: i32 = @as(i32, @intCast(image.height));
        const imageData: *const anyopaque = image.data.ptr;
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, imageData);
        gl.generateMipmap(gl.TEXTURE_2D);
        return texture;
    }

    pub fn initTransformsVBO(num_vertices: usize, attrib_var_loc: u32) !u32 {
        const instance_vbo = try initVBO();
        var instance_builder: *buffer_data.AttributeBuilder = try game.state.allocator.create(buffer_data.AttributeBuilder);
        defer game.state.allocator.destroy(instance_builder);
        instance_builder.* = buffer_data.AttributeBuilder.initWithLoc(
            @intCast(num_vertices),
            instance_vbo,
            gl.STATIC_DRAW,
            attrib_var_loc,
        );
        defer instance_builder.deinit();
        const col1_loc = instance_builder.defineFloatAttributeValueWithDivisor(4, true);
        const col2_loc = instance_builder.defineFloatAttributeValueWithDivisor(4, true);
        const col3_loc = instance_builder.defineFloatAttributeValueWithDivisor(4, true);
        const col4_loc = instance_builder.defineFloatAttributeValueWithDivisor(4, true);
        const r = zm.matToArr(zm.identity());
        instance_builder.initBuffer();
        instance_builder.addFloatAtLocation(col1_loc, @ptrCast(r[0..4]), 0);
        instance_builder.addFloatAtLocation(col2_loc, @ptrCast(r[4..8]), 0);
        instance_builder.addFloatAtLocation(col3_loc, @ptrCast(r[8..12]), 0);
        instance_builder.addFloatAtLocation(col4_loc, @ptrCast(r[12..16]), 0);
        instance_builder.nextVertex();
        instance_builder.write();
        return instance_vbo;
    }

    const lightingData = struct {
        ambient: [4]f32,
    };

    pub fn initLightingShaderStorageBufferObject(
        block_binding_point: u32,
    ) u32 {
        const ld: lightingData = .{
            .ambient = .{ 1, 1, 1, 1 },
        };
        var ssbo: u32 = undefined;
        gl.genBuffers(1, &ssbo);
        gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo);

        const struct_size = @sizeOf(lightingData);
        const size = @as(isize, @intCast(struct_size));
        gl.bufferData(gl.SHADER_STORAGE_BUFFER, size, &ld, gl.DYNAMIC_DRAW);
        gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, block_binding_point, ssbo);
        gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, 0);
        return ssbo;
    }
};
