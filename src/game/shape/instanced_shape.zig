const std = @import("std");
const gl = @import("zopengl").bindings;
const zstbi = @import("zstbi");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const view = @import("./view.zig");
const config = @import("../config.zig");
const data = @import("../data/data.zig");

pub const ShapeErr = error{
    NotInitialized,
    RenderError,
    UseProgramError,
    HighlightError,
    DrawingError,
    BindInstanceError,
    BindTextureError,
    UpdateError,
};

pub const textureDataType = enum {
    None,
    Image,
    RGBAColor,
};

pub const InstancedShapeVertex = struct {
    position: [3]gl.Float,
    texture: [2]gl.Float,
    rgbaColor: [4]gl.Float,
    barycentric: [3]gl.Float,
    edge: [2]gl.Float,
};

pub const InstancedShapeTransform = struct {
    transform: [16]gl.Float,
};

const bcV1 = @Vector(3, gl.Float){ 1.0, 0.0, 0.0 };
const bcV2 = @Vector(3, gl.Float){ 0.0, 1.0, 0.0 };
const bcV3 = @Vector(3, gl.Float){ 0.0, 0.0, 1.0 };

pub const InstancedShape = struct {
    blockId: i32,
    name: []const u8,
    vao: gl.Uint,
    vbo: gl.Uint,
    ebo: gl.Uint,
    texture: gl.Uint,
    numIndices: gl.Int,
    program: gl.Uint,
    highlight: gl.Int,
    instanceVBO: gl.Uint,
    numInstances: gl.Int,

    pub fn init(
        vm: *view.View,
        blockId: i32,
        name: []const u8,
        shape: zmesh.Shape,
        vertexShaderSource: [:0]const u8,
        fragmentShaderSource: [:0]const u8,
        rgbaColor: ?[4]gl.Float,
        textureRGBAColor: []const gl.Uint,
        alloc: std.mem.Allocator,
    ) !InstancedShape {
        const vao = try initVAO(name);
        const vertexShader = try initVertexShader(vertexShaderSource, name);
        const fragmentShader = try initFragmentShader(fragmentShaderSource, name);
        const vbo = try initVBO(name);
        const ebo = try initEBO(name, shape.indices);
        const program = try initProgram(name, &[_]gl.Uint{ vertexShader, fragmentShader });
        const texture = try initTextureFromColors(textureRGBAColor, name);
        const instancedVBO = try initData(name, shape, rgbaColor, alloc);
        try setUniforms(name, program, vm);
        return InstancedShape{
            .blockId = blockId,
            .name = name,
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
            .texture = texture,
            .numIndices = @intCast(shape.indices.len),
            .program = program,
            .highlight = 0,
            .instanceVBO = instancedVBO,
            .numInstances = 0,
        };
    }

    pub fn deinit(self: *const InstancedShape) void {
        gl.deleteVertexArrays(1, &self.vao);
        gl.deleteProgram(self.program);
        gl.deleteBuffers(1, &self.vbo);
        gl.deleteBuffers(1, &self.ebo);
        gl.deleteTextures(1, &self.texture);
        gl.deleteBuffers(1, &self.instanceVBO);
        return;
    }

    pub fn initVAO(_: []const u8) !gl.Uint {
        var VAO: gl.Uint = undefined;
        gl.genVertexArrays(1, &VAO);
        gl.bindVertexArray(VAO);
        return VAO;
    }

    pub fn initVBO(_: []const u8) !gl.Uint {
        var VBO: gl.Uint = undefined;
        gl.genBuffers(1, &VBO);
        gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
        return VBO;
    }

    pub fn initEBO(_: []const u8, indices: []const gl.Uint) !gl.Uint {
        var EBO: gl.Uint = undefined;
        gl.genBuffers(1, &EBO);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);

        const size = @as(isize, @intCast(indices.len * @sizeOf(gl.Uint)));
        const indicesptr: *const anyopaque = indices.ptr;
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, size, indicesptr, gl.STATIC_DRAW);
        return EBO;
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

    fn manageCubeTexturesCoordinates(vertices: []InstancedShapeVertex) []InstancedShapeVertex {
        for (0..vertices.len) |i| {
            // Since cube positions are merged via par_shapes meshes the precision is off, round the positions
            vertices[i].position[0] = @round(vertices[i].position[0]);
            vertices[i].position[1] = @round(vertices[i].position[1]);
            vertices[i].position[2] = @round(vertices[i].position[2]);

            // Adjust the texture coordinates for the cube
            // There are 36 vertices in a cube, each cube texture has 3 textures in one png across the y axis
            // The first texture is for the top, the second texture is for the sides and the third texture is for the bottom
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

    pub fn setUniforms(_: []const u8, program: gl.Uint, vm: *view.View) !void {
        gl.useProgram(program);

        gl.uniform1i(gl.getUniformLocation(program, "texture1"), 0);
        var projection: [16]gl.Float = [_]gl.Float{undefined} ** 16;

        const h = @as(gl.Float, @floatFromInt(config.windows_height));
        const w = @as(gl.Float, @floatFromInt(config.windows_width));
        const aspect = w / h;
        const ps = zm.perspectiveFovRh(config.fov, aspect, config.near, config.far);
        zm.storeMat(&projection, ps);

        const location = gl.getUniformLocation(program, "projection");
        gl.uniformMatrix4fv(location, 1, gl.FALSE, &projection);
        const blockIndex: gl.Uint = gl.getUniformBlockIndex(program, vm.name.ptr);
        const bindingPoint: gl.Uint = 0;
        gl.uniformBlockBinding(program, blockIndex, bindingPoint);
        gl.bindBufferBase(gl.UNIFORM_BUFFER, bindingPoint, vm.ubo);
    }

    fn initData(_: []const u8, shaderData: zmesh.Shape, rgbaColor: ?[4]gl.Float, alloc: std.mem.Allocator) !gl.Uint {
        var vertices = try std.ArrayList(InstancedShapeVertex).initCapacity(alloc, shaderData.positions.len);
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
            const vtx = InstancedShapeVertex{
                .position = shaderData.positions[i],
                .texture = tc,
                .rgbaColor = color,
                .barycentric = defaultBC,
                .edge = defaultEdge,
            };
            vertices.appendAssumeCapacity(vtx);
        }
        vertices.items = manageCubeTexturesCoordinates(vertices.items);
        const size = @as(isize, @intCast(vertices.items.len * @sizeOf(InstancedShapeVertex)));
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
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);

        // one transform matrix per instance with a default size of 1
        const idM = zm.identity();
        var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
        zm.storeMat(&transform, idM);
        const ist = InstancedShapeTransform{ .transform = transform };

        // init instanceVBO data
        var instanceVBO: gl.Uint = undefined;
        gl.genBuffers(1, &instanceVBO);
        gl.bindBuffer(gl.ARRAY_BUFFER, instanceVBO);
        gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(InstancedShapeTransform), &ist, gl.STATIC_DRAW);
        // have to set up 4 consecutive attributes for the matrix

        gl.enableVertexAttribArray(5);
        gl.vertexAttribPointer(5, 4, gl.FLOAT, gl.FALSE, @sizeOf(gl.Float) * 16, null);
        gl.enableVertexAttribArray(6);
        gl.vertexAttribPointer(6, 4, gl.FLOAT, gl.FALSE, @sizeOf(gl.Float) * 16, @as(*anyopaque, @ptrFromInt(@sizeOf(gl.Float) * 4)));
        gl.enableVertexAttribArray(7);
        gl.vertexAttribPointer(7, 4, gl.FLOAT, gl.FALSE, @sizeOf(gl.Float) * 16, @as(*anyopaque, @ptrFromInt(2 * @sizeOf(gl.Float) * 4)));
        gl.enableVertexAttribArray(8);
        gl.vertexAttribPointer(8, 4, gl.FLOAT, gl.FALSE, @sizeOf(gl.Float) * 16, @as(*anyopaque, @ptrFromInt(3 * @sizeOf(gl.Float) * 4)));

        gl.vertexAttribDivisor(5, 1);
        gl.vertexAttribDivisor(6, 1);
        gl.vertexAttribDivisor(7, 1);
        gl.vertexAttribDivisor(8, 1);
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);

        return instanceVBO;
    }

    pub fn updateInstanceData(self: *InstancedShape, transforms: []InstancedShapeTransform) !void {
        gl.useProgram(self.program);
        const size = @as(isize, @intCast(transforms.len * @sizeOf(InstancedShapeTransform)));
        const dataptr: *const anyopaque = transforms.ptr;
        gl.bindVertexArray(self.vao);
        gl.bindBuffer(gl.ARRAY_BUFFER, self.instanceVBO);
        gl.bufferData(gl.ARRAY_BUFFER, size, dataptr, gl.STATIC_DRAW);
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
        gl.bindVertexArray(0);
        self.numInstances = @as(gl.Int, @intCast(transforms.len));
        return;
    }

    pub fn draw(self: InstancedShape) !void {
        gl.useProgram(self.program);

        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, self.texture);

        gl.bindVertexArray(self.vao);

        // bind the instanceVBO
        gl.bindBuffer(gl.ARRAY_BUFFER, self.instanceVBO);

        gl.uniform1i(gl.getUniformLocation(self.program, "highlight"), self.highlight);

        // std.debug.print("drawing {s} with {d} instances\n", .{ self.name, self.numInstances });
        gl.drawElementsInstanced(gl.TRIANGLES, self.numIndices, gl.UNSIGNED_INT, null, self.numInstances);
    }
};
