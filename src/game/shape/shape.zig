const std = @import("std");
const gl = @import("zopengl").bindings;
const zstbi = @import("zstbi");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const gfx = @import("gfx/gfx.zig");
const config = @import("../config.zig");
const data = @import("../data/data.zig");

pub const ShapeErr = error{
    NotInitialized,
    RenderError,
};

pub const textureDataType = enum {
    None,
    Image,
    RGBAColor,
};

pub const ShapeConfig = struct {
    textureType: textureDataType,
    isCube: bool,
    hasPerspective: bool,
};

pub const ShapeVertex = struct {
    position: [3]gl.Float,
    texture: [2]gl.Float,
    rgbaColor: [4]gl.Float,
    barycentric: [3]gl.Float,
    edge: [2]gl.Float,
};

const bcV1 = @Vector(3, gl.Float){ 1.0, 0.0, 0.0 };
const bcV2 = @Vector(3, gl.Float){ 0.0, 1.0, 0.0 };
const bcV3 = @Vector(3, gl.Float){ 0.0, 0.0, 1.0 };

pub const Shape = struct {
    blockId: i32,
    name: []const u8,
    vao: gl.Uint,
    texture: gl.Uint,
    numIndices: gl.Int,
    program: gl.Uint,
    config: ShapeConfig,
    highlight: gl.Int,

    pub fn init(
        blockId: i32,
        name: []const u8,
        shape: zmesh.Shape,
        vertexShaderSource: [:0]const u8,
        fragmentShaderSource: [:0]const u8,
        img: ?[:0]const u8,
        rgbaColor: ?[4]gl.Float,
        textureRGBAColor: ?[]const gl.Uint,
        shapeConfig: ShapeConfig,
        alloc: std.mem.Allocator,
    ) !Shape {
        const vao = try gfx.Gfx.initVAO();
        const vertexShader = try initVertexShader(vertexShaderSource, name);
        const fragmentShader = try initFragmentShader(fragmentShaderSource, name);
        _ = try gfx.Gfx.initVBO();
        _ = try gfx.Gfx.initEBO(shape.indices);
        const program = try initProgram(name, &[_]gl.Uint{ vertexShader, fragmentShader });
        var texture: gl.Uint = undefined;
        var cfg = shapeConfig;
        switch (shapeConfig.textureType) {
            textureDataType.Image => {
                if (img) |i| {
                    texture = try initTexture(i, name);
                } else {
                    cfg.textureType = textureDataType.None;
                }
            },
            textureDataType.RGBAColor => {
                if (textureRGBAColor) |t| {
                    texture = try initTextureFromColors(t, name);
                } else {
                    cfg.textureType = textureDataType.None;
                }
            },
            else => {},
        }
        try initData(name, shape, shapeConfig, rgbaColor, alloc);
        try setUniforms(name, program, shapeConfig);
        return Shape{
            .blockId = blockId,
            .name = name,
            .vao = vao,
            .texture = texture,
            .numIndices = @intCast(shape.indices.len),
            .program = program,
            .config = cfg,
            .highlight = 0,
        };
    }

    pub fn deinit(self: *const Shape) void {
        gl.deleteVertexArrays(1, &self.vao);
        gl.deleteProgram(self.program);
        return;
    }

    pub fn initVertexShader(vertexShaderSource: [:0]const u8, msg: []const u8) !gl.Uint {
        var buffer: [100]u8 = undefined;
        const shaderMsg = try std.fmt.bufPrint(&buffer, "{s}: VERTEX", .{msg});
        return initShader(shaderMsg, vertexShaderSource, gl.VERTEX_SHADER);
    }

    pub fn initFragmentShader(fragmentShaderSource: [:0]const u8, msg: []const u8) !gl.Uint {
        var buffer: [100]u8 = undefined;
        const shaderMsg = try std.fmt.bufPrint(&buffer, "{s}: FRAGMENT", .{msg});
        return initShader(shaderMsg, fragmentShaderSource, gl.FRAGMENT_SHADER);
    }

    pub fn initShader(name: []const u8, source: [:0]const u8, shaderType: c_uint) !gl.Uint {
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
            return ShapeErr.RenderError;
        }

        return shader;
    }

    pub fn initProgram(name: []const u8, shaders: []const gl.Uint) !gl.Uint {
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
            std.debug.print("ERROR::SHADER::{s}::PROGRAM::LINKING_FAILED\n{s}\n", .{ name, infoLog[0..i] });
            return ShapeErr.RenderError;
        }

        for (shaders) |shader| {
            gl.deleteShader(shader);
        }
        return shaderProgram;
    }

    pub fn initTextureFromColors(textureData: []const gl.Uint, _: []const u8) !gl.Uint {
        var texture: gl.Uint = undefined;
        gl.genTextures(1, &texture);
        gl.bindTexture(gl.TEXTURE_2D, texture);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        const width: gl.Int = 16;
        const height: gl.Int = @divFloor(@as(gl.Int, @intCast(textureData.len)), width);
        const imageData: *const anyopaque = textureData.ptr;
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, imageData);
        gl.generateMipmap(gl.TEXTURE_2D);
        return texture;
    }

    pub fn initTexture(img: [:0]const u8, _: []const u8) !gl.Uint {
        var texture: gl.Uint = undefined;
        gl.genTextures(1, &texture);
        gl.bindTexture(gl.TEXTURE_2D, texture);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        var image = try zstbi.Image.loadFromMemory(img, 4);
        defer image.deinit();

        const width: gl.Int = @as(gl.Int, @intCast(image.width));
        const height: gl.Int = @as(gl.Int, @intCast(image.height));
        const imageData: *const anyopaque = image.data.ptr;
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, imageData);
        gl.generateMipmap(gl.TEXTURE_2D);
        return texture;
    }

    fn manageCubeTexturesCoordinates(vertices: []ShapeVertex) []ShapeVertex {
        for (0..vertices.len) |i| {
            // Since cube positions are merged via par_shapes meshes the precision is off, round the positions
            vertices[i].position[0] = @round(vertices[i].position[0]);
            vertices[i].position[1] = @round(vertices[i].position[1]);
            vertices[i].position[2] = @round(vertices[i].position[2]);

            // Adjust the texture coordinates for the cube
            // There are 36 vertices in a cube, each cube texture has 3 textures in one png across the y axis
            // The first texture is for the to, the second texture is for the sides and the third texture is for the top
            // This function iterates through the 36 vertices and assigns the correct texture coordinates to each vertex
            // and adjusts for the width of each texture being a third of the total width of the png
            vertices[i].edge = vertices[i].texture;
            if (vertices[i].texture[1] > 0.0) {
                vertices[i].texture[1] = 0.3333333333333333;
            }
            if (i < 4) {}
            if (i >= 4 and i < 8) {
                vertices[i].texture[1] += 0.333333333333333;
            }
            if (i >= 8 and i < 12) {
                vertices[i].texture[1] += 0.333333333333333;
            }
            if (i >= 12 and i < 16) {
                vertices[i].texture[1] += 0.333333333333333;
            }
            if (i >= 16 and i < 20) {
                vertices[i].texture[1] += 0.333333333333333;
            }
            if (i >= 20 and i < 24) {
                vertices[i].texture[1] += 0.666666666666666;
            }
            // Set barycentric coordinates for the cube
            switch (@mod(i, 6)) {
                0 => vertices[i].barycentric = bcV1,
                1 => vertices[i].barycentric = bcV2,
                2 => vertices[i].barycentric = bcV3,
                3 => vertices[i].barycentric = bcV1,
                4 => vertices[i].barycentric = bcV2,
                5 => vertices[i].barycentric = bcV3,
                else => unreachable,
            }
        }
        return vertices;
    }

    fn initData(_: []const u8, shaderData: zmesh.Shape, shapeConfig: ShapeConfig, rgbaColor: ?[4]gl.Float, alloc: std.mem.Allocator) !void {
        var vertices = try std.ArrayList(ShapeVertex).initCapacity(alloc, shaderData.positions.len);
        defer vertices.deinit();

        var tc: [2]gl.Float = [_]gl.Float{ 0.0, 0.0 };
        var color: [4]gl.Float = [_]gl.Float{ 1.0, 1.0, 1.0, 1.0 };
        for (0..shaderData.positions.len) |i| {
            if (shaderData.texcoords) |t| {
                tc = t[i];
            }
            if (rgbaColor) |c| {
                color = c;
            }
            const defaultBC = @Vector(3, gl.Float){ 0.0, 0.0, 0.0 };
            const defaultEdge = @Vector(2, gl.Float){ 0.0, 0.0 };
            const vtx = ShapeVertex{
                .position = shaderData.positions[i],
                .texture = tc,
                .rgbaColor = color,
                .barycentric = defaultBC,
                .edge = defaultEdge,
            };
            vertices.appendAssumeCapacity(vtx);
        }
        if (shapeConfig.isCube) {
            vertices.items = manageCubeTexturesCoordinates(vertices.items);
        }
        const size = @as(isize, @intCast(vertices.items.len * @sizeOf(ShapeVertex)));
        const dataptr: *const anyopaque = vertices.items.ptr;
        gl.bufferData(gl.ARRAY_BUFFER, size, dataptr, gl.STATIC_DRAW);
        const posSize: gl.Int = 3;
        const texSize: gl.Int = 2;
        const colorSize: gl.Int = 4;
        const barycentricSize: gl.Int = 3;
        const edgeSize: gl.Int = 2;
        const stride: gl.Int = posSize + texSize + colorSize + barycentricSize + edgeSize;
        var offset: gl.Uint = posSize;
        var curArr: gl.Uint = 0;
        gl.vertexAttribPointer(curArr, posSize, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), null);
        gl.enableVertexAttribArray(curArr);
        curArr += 1;
        gl.vertexAttribPointer(curArr, texSize, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), @as(*anyopaque, @ptrFromInt(offset * @sizeOf(gl.Float))));
        gl.enableVertexAttribArray(curArr);
        offset += texSize;
        curArr += 1;
        gl.vertexAttribPointer(curArr, colorSize, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), @as(*anyopaque, @ptrFromInt(offset * @sizeOf(gl.Float))));
        gl.enableVertexAttribArray(curArr);
        offset += colorSize;
        curArr += 1;
        gl.vertexAttribPointer(curArr, barycentricSize, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), @as(*anyopaque, @ptrFromInt(offset * @sizeOf(gl.Float))));
        gl.enableVertexAttribArray(curArr);
        offset += barycentricSize;
        curArr += 1;
        gl.vertexAttribPointer(curArr, edgeSize, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), @as(*anyopaque, @ptrFromInt(offset * @sizeOf(gl.Float))));
        gl.enableVertexAttribArray(curArr);
        offset += edgeSize;
        curArr += 1;
    }

    pub fn setUniforms(_: []const u8, program: gl.Uint, shapeConfig: ShapeConfig) !void {
        gl.useProgram(program);
        if (shapeConfig.textureType != textureDataType.None) {
            gl.uniform1i(gl.getUniformLocation(program, "texture1"), 0);
        }
        var projection: [16]gl.Float = [_]gl.Float{undefined} ** 16;

        const h = @as(gl.Float, @floatFromInt(config.windows_height));
        const w = @as(gl.Float, @floatFromInt(config.windows_width));
        const aspect = w / h;
        const ps = zm.perspectiveFovRh(config.fov, aspect, config.near, config.far);
        zm.storeMat(&projection, ps);

        const location = gl.getUniformLocation(program, "projection");
        gl.uniformMatrix4fv(location, 1, gl.FALSE, &projection);
    }

    pub fn draw(self: Shape, tf: ?zm.Mat) !void {
        gl.useProgram(self.program);

        if (self.config.textureType != textureDataType.None) {
            gl.activeTexture(gl.TEXTURE0);
            gl.bindTexture(gl.TEXTURE_2D, self.texture);
        }

        gl.bindVertexArray(self.vao);

        var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
        if (tf) |t| {
            zm.storeMat(&transform, zm.transpose(t));
        } else {
            zm.storeMat(&transform, zm.transpose(zm.identity()));
        }
        const location = gl.getUniformLocation(self.program, "transform");
        gl.uniformMatrix4fv(location, 1, gl.TRUE, &transform);

        gl.uniform1i(gl.getUniformLocation(self.program, "highlight"), self.highlight);

        if (!self.config.hasPerspective) {
            //disable depth test for ortho
            gl.disable(gl.DEPTH_TEST);
        }

        gl.drawElements(gl.TRIANGLES, self.numIndices, gl.UNSIGNED_INT, null);
        // renable depth test
        gl.enable(gl.DEPTH_TEST);
    }
};
