const std = @import("std");
const gl = @import("zopengl");
const zstbi = @import("zstbi");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const config = @import("../config.zig");
const view = @import("./view.zig");
const data = @import("../data/data.zig");

pub const VoxelShapeErr = error{
    NotInitialized,
    RenderError,
};

pub const VoxelShapeVertex = struct {
    position: [3]gl.Float,
    texture: [2]gl.Float,
    barycentric: [3]gl.Float,
    edge: [2]gl.Float,
    normal: [3]gl.Float,
};

const bcV1 = @Vector(3, gl.Float){ 1.0, 0.0, 0.0 };
const bcV2 = @Vector(3, gl.Float){ 0.0, 1.0, 0.0 };
const bcV3 = @Vector(3, gl.Float){ 0.0, 0.0, 1.0 };

pub const VoxelData = struct {
    blockId: i32,
    vao: gl.Uint,
    vbo: gl.Uint,
    ebo: gl.Uint,
    numIndices: gl.Int,
    worldspaceVBO: gl.Uint,
    pub fn init(
        blockId: i32,
        shape: zmesh.Shape,
        worldTransform: [16]gl.Float,
        alloc: std.mem.Allocator,
    ) !VoxelData {
        const vao = try initVAO(blockId);
        const vbo = try initVBO(blockId);
        const ebo = try initEBO(blockId, shape.indices);
        const worldspaceVBO = try initData(blockId, shape, worldTransform, alloc);
        return VoxelData{
            .blockId = blockId,
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
            .numIndices = @intCast(shape.indices.len),
            .worldspaceVBO = worldspaceVBO,
        };
    }

    pub fn deinit(self: VoxelData) void {
        gl.deleteVertexArrays(1, &self.vao);
        gl.deleteBuffers(1, &self.vbo);
        gl.deleteBuffers(1, &self.ebo);
        gl.deleteBuffers(1, &self.worldspaceVBO);
        return;
    }
    pub fn initVAO(blockId: i32) !gl.Uint {
        var VAO: gl.Uint = undefined;
        gl.genVertexArrays(1, &VAO);
        gl.bindVertexArray(VAO);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("voxel init vao error blockId: {d} - {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }
        return VAO;
    }

    pub fn initVBO(blockId: i32) !gl.Uint {
        var VBO: gl.Uint = undefined;
        gl.genBuffers(1, &VBO);
        gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("voxel init vbo error blockId: {d} - {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }
        return VBO;
    }

    pub fn initEBO(blockId: i32, indices: []const gl.Uint) !gl.Uint {
        var EBO: gl.Uint = undefined;
        gl.genBuffers(1, &EBO);
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("voxel init ebo error blockId: {d} - {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("voxel bind ebo buff error blockId: {d} - {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }

        const size = @as(isize, @intCast(indices.len * @sizeOf(gl.Uint)));
        const indicesptr: *const anyopaque = indices.ptr;
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, size, indicesptr, gl.STATIC_DRAW);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("voxel buffer data error blockId: {d} - {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }
        return EBO;
    }

    fn initData(blockId: i32, shaderData: zmesh.Shape, worldspaceTF: [16]gl.Float, alloc: std.mem.Allocator) !gl.Uint {
        var vertices = try std.ArrayList(VoxelShapeVertex).initCapacity(alloc, shaderData.positions.len);
        defer vertices.deinit();

        var tc: [2]gl.Float = [_]gl.Float{ 0.0, 0.0 };
        var nm: [3]gl.Float = [_]gl.Float{ 0.0, 0.0, 0.0 };
        for (0..shaderData.positions.len) |i| {
            if (shaderData.texcoords) |t| {
                tc = t[i];
            }
            if (shaderData.normals) |n| {
                nm = n[i];
            }
            const defaultBC = @Vector(3, gl.Float){ 0.0, 0.0, 0.0 };
            const defaultEdge = @Vector(2, gl.Float){ 0.0, 0.0 };
            const vtx = VoxelShapeVertex{
                .position = shaderData.positions[i],
                .texture = tc,
                .barycentric = defaultBC,
                .edge = defaultEdge,
                .normal = nm,
            };
            vertices.appendAssumeCapacity(vtx);
        }
        const size = @as(isize, @intCast(vertices.items.len * @sizeOf(VoxelShapeVertex)));
        const dataptr: *const anyopaque = vertices.items.ptr;
        gl.bufferData(gl.ARRAY_BUFFER, size, dataptr, gl.STATIC_DRAW);
        const posSize: gl.Int = 3;
        const texSize: gl.Int = 2;
        const barycentricSize: gl.Int = 3;
        const edgeSize: gl.Int = 2;
        const normalSize: gl.Int = 3;
        const stride: gl.Int = posSize + texSize + barycentricSize + edgeSize + normalSize;
        var offset: gl.Uint = posSize;
        var curArr: gl.Uint = 0;
        gl.vertexAttribPointer(curArr, posSize, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), null);
        gl.enableVertexAttribArray(curArr);
        curArr += 1;
        gl.vertexAttribPointer(curArr, texSize, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), @as(*anyopaque, @ptrFromInt(offset * @sizeOf(gl.Float))));
        gl.enableVertexAttribArray(curArr);
        offset += texSize;
        curArr += 1;
        gl.vertexAttribPointer(curArr, barycentricSize, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), @as(*anyopaque, @ptrFromInt(offset * @sizeOf(gl.Float))));
        gl.enableVertexAttribArray(curArr);
        offset += barycentricSize;
        curArr += 1;
        gl.vertexAttribPointer(curArr, edgeSize, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), @as(*anyopaque, @ptrFromInt(offset * @sizeOf(gl.Float))));
        gl.enableVertexAttribArray(curArr);
        curArr += 1;
        offset += edgeSize;
        gl.vertexAttribPointer(curArr, normalSize, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), @as(*anyopaque, @ptrFromInt(offset * @sizeOf(gl.Float))));
        gl.enableVertexAttribArray(curArr);
        curArr += 1;
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} voxel init data error: {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);

        // init worldspace VBO data
        var worldspaceVBO: gl.Uint = undefined;
        gl.genBuffers(1, &worldspaceVBO);
        gl.bindBuffer(gl.ARRAY_BUFFER, worldspaceVBO);

        const tfSize = @as(isize, @intCast(worldspaceTF.len * @sizeOf(gl.Float)));
        gl.bufferData(gl.ARRAY_BUFFER, tfSize, &worldspaceTF, gl.STATIC_DRAW);
        // have to set up 4 consecutive attributes for the matrix
        offset = 0;
        for (0..4) |i| {
            gl.enableVertexAttribArray(curArr);
            if (i == 0) {
                gl.vertexAttribPointer(curArr, 4, gl.FLOAT, gl.FALSE, @sizeOf(gl.Float) * 16, null);
            } else {
                gl.vertexAttribPointer(curArr, 4, gl.FLOAT, gl.FALSE, @sizeOf(gl.Float) * 16, @as(*anyopaque, @ptrFromInt(offset * @sizeOf(gl.Float))));
            }
            gl.vertexAttribDivisor(curArr, 1);
            curArr += 1;
            offset += 4;
        }
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);

        return worldspaceVBO;
    }

    pub fn draw(self: VoxelData) !void {
        gl.bindVertexArray(self.vao);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} voxel draw bind vertex array error: {d}\n", .{ self.blockId, e });
            return VoxelShapeErr.RenderError;
        }

        gl.drawElements(gl.TRIANGLES, self.numIndices, gl.UNSIGNED_INT, null);
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} voxel draw draw elements error: {d}\n", .{ self.blockId, e });
            return VoxelShapeErr.RenderError;
        }
    }
};

pub const VoxelShape = struct {
    blockId: i32,
    texture: gl.Uint,
    program: gl.Uint,
    voxelData: std.ArrayList(VoxelData),
    alloc: std.mem.Allocator,

    pub fn init(
        vm: view.View,
        blockId: i32,
        vertexShaderSource: [:0]const u8,
        fragmentShaderSource: [:0]const u8,
        textureRGBAColor: []const gl.Uint,
        alloc: std.mem.Allocator,
    ) !VoxelShape {
        const vertexShader = try initVertexShader(blockId, vertexShaderSource);
        const fragmentShader = try initFragmentShader(blockId, fragmentShaderSource);
        const program = try initProgram(blockId, &[_]gl.Uint{ vertexShader, fragmentShader });
        const texture = try initTextureFromColors(blockId, textureRGBAColor);
        try setUniforms(blockId, program, vm);
        return VoxelShape{
            .blockId = blockId,
            .texture = texture,
            .program = program,
            .voxelData = std.ArrayList(VoxelData).init(alloc),
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *const VoxelShape) void {
        gl.deleteProgram(self.program);
        gl.deleteTextures(1, &self.texture);
        for (self.voxelData.items) |vs| {
            vs.deinit();
        }
        self.voxelData.deinit();
        return;
    }

    pub fn addVoxelData(
        self: *VoxelShape,
        shape: zmesh.Shape,
        worldTransform: [16]gl.Float,
    ) !void {
        gl.useProgram(self.program);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} voxel draw error: {d}\n", .{ self.blockId, e });
            return VoxelShapeErr.RenderError;
        }
        var vd = try VoxelData.init(self.blockId, shape, worldTransform, self.alloc);
        _ = &vd;
        try self.voxelData.append(vd);
        return;
    }

    pub fn clear(self: *VoxelShape) void {
        for (self.voxelData.items) |vs| {
            vs.deinit();
        }
        self.voxelData.clearRetainingCapacity();
    }

    pub fn initVertexShader(blockId: i32, vertexShaderSource: [:0]const u8) !gl.Uint {
        var buffer: [100]u8 = undefined;
        const shaderMsg = try std.fmt.bufPrint(&buffer, "{d}: VERTEX", .{blockId});
        return initShader(shaderMsg, vertexShaderSource, gl.VERTEX_SHADER);
    }

    pub fn initFragmentShader(blockId: i32, fragmentShaderSource: [:0]const u8) !gl.Uint {
        var buffer: [100]u8 = undefined;
        const shaderMsg = try std.fmt.bufPrint(&buffer, "{d}: FRAGMENT", .{blockId});
        return initShader(shaderMsg, fragmentShaderSource, gl.FRAGMENT_SHADER);
    }

    pub fn initShader(msg: []u8, source: [:0]const u8, shaderType: c_uint) !gl.Uint {
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
            std.debug.print("ERROR::SHADER::{s}::COMPILATION_FAILED\n{s}\n", .{ msg, infoLog[0..i] });
            return VoxelShapeErr.RenderError;
        }

        return shader;
    }

    pub fn initProgram(blockId: i32, shaders: []const gl.Uint) !gl.Uint {
        const shaderProgram: gl.Uint = gl.createProgram();
        for (shaders) |shader| {
            gl.attachShader(shaderProgram, shader);
        }
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("init voxel program {d} error: {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }

        gl.linkProgram(shaderProgram);
        var success: gl.Int = 0;
        gl.getProgramiv(shaderProgram, gl.LINK_STATUS, &success);
        if (success == 0) {
            var infoLog: [512]u8 = undefined;
            var logSize: gl.Int = 0;
            gl.getProgramInfoLog(shaderProgram, 512, &logSize, &infoLog);
            const i: usize = @intCast(logSize);
            std.debug.print("ERROR::SHADER::{d}::PROGRAM::LINKING_FAILED\n{s}\n", .{ blockId, infoLog[0..i] });
            return VoxelShapeErr.RenderError;
        }

        for (shaders) |shader| {
            gl.deleteShader(shader);
        }

        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} voxel error: {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }
        return shaderProgram;
    }

    pub fn initTextureFromColors(blockId: i32, textureData: []const gl.Uint) !gl.Uint {
        var texture: gl.Uint = undefined;
        var e: gl.Uint = 0;
        gl.genTextures(1, &texture);
        gl.bindTexture(gl.TEXTURE_2D, texture);
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} voxel gen or bind texture error: {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} voxel text parameter i error: {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }

        const width: gl.Int = 16;
        const height: gl.Int = @divFloor(@as(gl.Int, @intCast(textureData.len)), width);
        const imageData: *const anyopaque = textureData.ptr;
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, imageData);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} voxel gext image 2d error: {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }
        gl.generateMipmap(gl.TEXTURE_2D);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} voxel generate mimap error: {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }
        return texture;
    }

    pub fn setUniforms(blockId: i32, program: gl.Uint, vm: view.View) !void {
        gl.useProgram(program);
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} voxel set uniforms error: {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }

        gl.uniform1i(gl.getUniformLocation(program, "texture1"), 0);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} voxel uniform1i error: {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }
        var projection: [16]gl.Float = [_]gl.Float{undefined} ** 16;

        const h = @as(gl.Float, @floatFromInt(config.windows_height));
        const w = @as(gl.Float, @floatFromInt(config.windows_width));
        const aspect = w / h;
        const ps = zm.perspectiveFovRh(config.fov, aspect, config.near, config.far);
        zm.storeMat(&projection, ps);

        const location = gl.getUniformLocation(program, "projection");
        gl.uniformMatrix4fv(location, 1, gl.FALSE, &projection);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("error: {d}\n", .{e});
            return VoxelShapeErr.RenderError;
        }
        const blockIndex: gl.Uint = gl.getUniformBlockIndex(program, vm.name.ptr);
        const bindingPoint: gl.Uint = 0;
        gl.uniformBlockBinding(program, blockIndex, bindingPoint);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("voxel error blockId: {d} - {d}\n", .{ blockId, e });
            return VoxelShapeErr.RenderError;
        }
        gl.bindBufferBase(gl.UNIFORM_BUFFER, bindingPoint, vm.ubo);
    }

    pub fn draw(self: VoxelShape) !void {
        gl.useProgram(self.program);
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} voxel draw error: {d}\n", .{ self.blockId, e });
            return VoxelShapeErr.RenderError;
        }

        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, self.texture);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} voxel draw bind texture error: {d}\n", .{ self.blockId, e });
            return VoxelShapeErr.RenderError;
        }

        for (self.voxelData.items) |vs| {
            try vs.draw();
        }
    }
};
