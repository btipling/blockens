const std = @import("std");
const gl = @import("zopengl");
const zstbi = @import("zstbi");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const config = @import("config.zig");

pub const ShapeErr = error{Error};

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

pub const RGBAColorTextureSize = 3 * 16 * 16;

const bcV1 = @Vector(3, gl.Float){ 1.0, 0.0, 0.0 };
const bcV2 = @Vector(3, gl.Float){ 0.0, 1.0, 0.0 };
const bcV3 = @Vector(3, gl.Float){ 0.0, 0.0, 1.0 };

pub const Shape = struct {
    name: []const u8,
    vao: gl.Uint,
    texture: gl.Uint,
    numIndices: gl.Int,
    program: gl.Uint,
    config: ShapeConfig,
    highlight: gl.Int,

    pub fn init(
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
        const vao = try initVAO(name);
        const vertexShader = try initVertexShader(vertexShaderSource, name);
        const fragmentShader = try initFragmentShader(fragmentShaderSource, name);
        try initVBO(name);
        try initEBO(name, shape.indices);
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
                    std.debug.print("no texture colors for {s}\n", .{name});
                    cfg.textureType = textureDataType.None;
                }
            },
            else => std.debug.print("no texture for {s}\n", .{name}),
        }
        try initData(name, shape, shapeConfig, rgbaColor, alloc);
        try setUniforms(name, program, shapeConfig);
        return Shape{
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

    pub fn initVAO(msg: []const u8) !gl.Uint {
        var VAO: gl.Uint = undefined;
        gl.genVertexArrays(1, &VAO);
        gl.bindVertexArray(VAO);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("init vao error: {s} {d}\n", .{ msg, e });
            return ShapeErr.Error;
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
            return ShapeErr.Error;
        }
        return;
    }

    pub fn initEBO(msg: []const u8, indices: []const gl.Uint) !void {
        var EBO: gl.Uint = undefined;
        gl.genBuffers(1, &EBO);
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("init ebo error: {s} {d}\n", .{ msg, e });
            return ShapeErr.Error;
        }
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("bind ebo buff error: {s} {d}\n", .{ msg, e });
            return ShapeErr.Error;
        }

        const size = @as(isize, @intCast(indices.len * @sizeOf(gl.Uint)));
        const indicesptr: *const anyopaque = indices.ptr;
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, size, indicesptr, gl.STATIC_DRAW);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} buffer data error: {d}\n", .{ msg, e });
            return ShapeErr.Error;
        }
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
            return ShapeErr.Error;
        }

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
            return ShapeErr.Error;
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
            return ShapeErr.Error;
        }

        for (shaders) |shader| {
            gl.deleteShader(shader);
        }

        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} error: {d}\n", .{ name, e });
            return ShapeErr.Error;
        }
        return shaderProgram;
    }

    pub fn initTextureFromColors(data: []const gl.Uint, msg: []const u8) !gl.Uint {
        var texture: gl.Uint = undefined;
        var e: gl.Uint = 0;
        gl.genTextures(1, &texture);
        gl.bindTexture(gl.TEXTURE_2D, texture);
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} gen or bind texture error: {d}\n", .{ msg, e });
            return ShapeErr.Error;
        }

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} text parameter i error: {d}\n", .{ msg, e });
            return ShapeErr.Error;
        }

        const width: gl.Int = 16;
        const height: gl.Int = @divFloor(@as(gl.Int, @intCast(data.len)), width);
        const imageData: *const anyopaque = data.ptr;
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, imageData);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} gext image 2d error: {d}\n", .{ msg, e });
            return ShapeErr.Error;
        }
        gl.generateMipmap(gl.TEXTURE_2D);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} generate mimap error: {d}\n", .{ msg, e });
            return ShapeErr.Error;
        }
        return texture;
    }

    pub fn initTexture(img: [:0]const u8, msg: []const u8) !gl.Uint {
        var texture: gl.Uint = undefined;
        var e: gl.Uint = 0;
        gl.genTextures(1, &texture);
        gl.bindTexture(gl.TEXTURE_2D, texture);
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} gen or bind texture error: {d}\n", .{ msg, e });
            return ShapeErr.Error;
        }

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} text parameter i error: {d}\n", .{ msg, e });
            return ShapeErr.Error;
        }

        var image = try zstbi.Image.loadFromMemory(img, 4);
        defer image.deinit();

        const width: gl.Int = @as(gl.Int, @intCast(image.width));
        const height: gl.Int = @as(gl.Int, @intCast(image.height));
        const imageData: *const anyopaque = image.data.ptr;
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, imageData);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} gext image 2d error: {d}\n", .{ msg, e });
            return ShapeErr.Error;
        }
        gl.generateMipmap(gl.TEXTURE_2D);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} generate mimap error: {d}\n", .{ msg, e });
            return ShapeErr.Error;
        }
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

    fn initData(name: []const u8, data: zmesh.Shape, shapeConfig: ShapeConfig, rgbaColor: ?[4]gl.Float, alloc: std.mem.Allocator) !void {
        var vertices = try std.ArrayList(ShapeVertex).initCapacity(alloc, data.positions.len);
        defer vertices.deinit();

        var tc: [2]gl.Float = [_]gl.Float{ 0.0, 0.0 };
        var color: [4]gl.Float = [_]gl.Float{ 1.0, 1.0, 1.0, 1.0 };
        for (0..data.positions.len) |i| {
            if (data.texcoords) |t| {
                tc = t[i];
            }
            if (rgbaColor) |c| {
                color = c;
            }
            const defaultBC = @Vector(3, gl.Float){ 0.0, 0.0, 0.0 };
            const defaultEdge = @Vector(2, gl.Float){ 0.0, 0.0 };
            const vtx = ShapeVertex{
                .position = data.positions[i],
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
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} init data error: {d}\n", .{ name, e });
            return ShapeErr.Error;
        }
    }

    pub fn setUniforms(name: []const u8, program: gl.Uint, shapeConfig: ShapeConfig) !void {
        gl.useProgram(program);
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} error: {d}\n", .{ name, e });
            return ShapeErr.Error;
        }

        if (shapeConfig.textureType != textureDataType.None) {
            gl.uniform1i(gl.getUniformLocation(program, "texture1"), 0);
            e = gl.getError();
            if (e != gl.NO_ERROR) {
                std.debug.print("{s} uniform1i error: {d}\n", .{ name, e });
                return ShapeErr.Error;
            }
        }
        var projection: [16]gl.Float = [_]gl.Float{undefined} ** 16;

        const fov = 45.0;
        const h = @as(gl.Float, @floatFromInt(config.windows_height));
        const w = @as(gl.Float, @floatFromInt(config.windows_width));
        const aspect = w / h;
        var ps = zm.perspectiveFovRh(fov, aspect, 0.1, 100.0);
        if (shapeConfig.hasPerspective) {
            ps = zm.perspectiveFovRh(fov, aspect, 0.1, 100.0);
        } else {
            // todo: make this work
            // ps = zm.orthographicRh(-1.0, 1.0, -1.0, 100.0);
        }
        zm.storeMat(&projection, ps);

        const location = gl.getUniformLocation(program, "projection");
        gl.uniformMatrix4fv(location, 1, gl.FALSE, &projection);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("error: {d}\n", .{e});
            return ShapeErr.Error;
        }
    }

    pub fn draw(self: Shape, tf: ?zm.Mat) !void {
        gl.useProgram(self.program);
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} error: {d}\n", .{ self.name, e });
            return ShapeErr.Error;
        }

        if (self.config.textureType != textureDataType.None) {
            gl.activeTexture(gl.TEXTURE0);
            gl.bindTexture(gl.TEXTURE_2D, self.texture);
            e = gl.getError();
            if (e != gl.NO_ERROR) {
                std.debug.print("{s} bind texture error: {d}\n", .{ self.name, e });
                return ShapeErr.Error;
            }
        }

        gl.bindVertexArray(self.vao);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} bind vertex array error: {d}\n", .{ self.name, e });
            return ShapeErr.Error;
        }

        var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
        if (tf) |t| {
            zm.storeMat(&transform, zm.transpose(t));
        } else {
            zm.storeMat(&transform, zm.transpose(zm.identity()));
        }
        const location = gl.getUniformLocation(self.program, "transform");
        gl.uniformMatrix4fv(location, 1, gl.TRUE, &transform);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("error: {d}\n", .{e});
            return ShapeErr.Error;
        }

        gl.uniform1i(gl.getUniformLocation(self.program, "highlight"), self.highlight);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("error setting highlighted: {d}\n", .{e});
            return ShapeErr.Error;
        }

        if (!self.config.hasPerspective) {
            //disable depth test for ortho
            gl.disable(gl.DEPTH_TEST);
        }

        gl.drawElements(gl.TRIANGLES, self.numIndices, gl.UNSIGNED_INT, null);
        if (e != gl.NO_ERROR) {
            std.debug.print("{s} draw elements error: {d}\n", .{ self.name, e });
            return ShapeErr.Error;
        }
        // renable depth test
        gl.enable(gl.DEPTH_TEST);
    }
};
