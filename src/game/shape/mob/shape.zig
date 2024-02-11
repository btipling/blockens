const std = @import("std");
const gl = @import("zopengl");
const zstbi = @import("zstbi");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const config = @import("../../config.zig");
const view = @import("./view.zig");
const gfx = @import("../gfx/gfx.zig");
const data = @import("../../data/data.zig");

pub const ShapeErr = error{
    NotInitialized,
    RenderError,
};

pub const ShapeVertex = struct {
    position: [3]gl.Float,
    normals: [3]gl.Float,
    textcoords: [2]gl.Float,
    baseColor: [4]gl.Float,
};

pub const ShapeAnimation = struct {
    rotation: ?[4]gl.Float = null,
    translation: ?[3]gl.Float = null,
    animationTransform: [16]gl.Float,
};

pub const ShapeTransform = struct {
    parent: ?*ShapeTransform = null,
    transform: ?[16]gl.Float = null,
    rotation: ?[4]gl.Float = null,
    translation: ?[3]gl.Float = null,
    scale: ?[3]gl.Float = null,

    fn translationM(self: ShapeTransform) zm.Mat {
        var m = zm.identity();
        if (self.parent) |p| {
            m = p.translationM();
        }
        if (self.translation) |t| {
            return zm.mul(zm.translation(t[0], t[1], t[2]), m);
        }
        return m;
    }

    fn rotationM(self: ShapeTransform) zm.Mat {
        var m = zm.identity();
        if (self.parent) |p| {
            m = p.rotationM();
        }
        if (self.rotation) |r| {
            return zm.mul(zm.matFromQuat(r), m);
        }
        return m;
    }

    fn scaleM(self: ShapeTransform) zm.Mat {
        var m = zm.identity();
        if (self.parent) |p| {
            m = p.scaleM();
        }
        if (self.scale) |s| {
            return zm.mul(zm.scaling(s[0], s[1], s[2]), m);
        }
        return m;
    }
};

pub const ShapeData = struct {
    indices: std.ArrayList(u32),
    positions: std.ArrayList([3]gl.Float),
    normals: std.ArrayList([3]gl.Float),
    textcoords: std.ArrayList([2]gl.Float),
    tangents: std.ArrayList([4]gl.Float),
    baseColor: [4]gl.Float,
    localTransform: *ShapeTransform,
    animationTranslation: zm.Mat,
    animationRotation: zm.Mat,
    animate: bool = true,
    textureData: ?[]u8,
    animationData: ?std.AutoHashMap(u32, ShapeAnimation),

    pub fn init(
        alloc: std.mem.Allocator,
        baseColor: [4]gl.Float,
        localTransform: *ShapeTransform,
        textureData: ?[]u8,
        animationData: ?std.AutoHashMap(u32, ShapeAnimation),
    ) ShapeData {
        var animationTranslation = zm.identity();
        if (localTransform.translation) |t| {
            animationTranslation = zm.translation(t[0], t[1], t[2]);
        }
        var animationRotation = zm.identity();
        if (localTransform.rotation) |r| {
            animationRotation = zm.matFromQuat(r);
        }
        return .{
            .indices = std.ArrayList(u32).init(alloc),
            .positions = std.ArrayList([3]gl.Float).init(alloc),
            .normals = std.ArrayList([3]gl.Float).init(alloc),
            .textcoords = std.ArrayList([2]gl.Float).init(alloc),
            .tangents = std.ArrayList([4]gl.Float).init(alloc),
            .baseColor = baseColor,
            .localTransform = localTransform,
            .animationTranslation = animationTranslation,
            .animationRotation = animationRotation,
            .textureData = textureData,
            .animationData = animationData,
        };
    }

    pub fn deinit(self: ShapeData) void {
        self.indices.deinit();
        self.positions.deinit();
        self.normals.deinit();
        self.textcoords.deinit();
        self.tangents.deinit();
    }

    fn currentFrame(_: ShapeData) u32 {
        const now = @as(u64, @intCast(std.time.milliTimestamp()));
        const clearFrame: u64 = 10;
        const frameSet = @mod((now / clearFrame) * clearFrame, 2000);
        return @as(u32, @intCast(frameSet));
    }

    fn translationM(self: *ShapeData) zm.Mat {
        if (self.animationData) |ad| {
            if (ad.get(self.currentFrame())) |sa| {
                if (self.animate) {
                    if (sa.translation) |t| {
                        self.animationTranslation = zm.translation(t[0], t[1], t[2]);
                    }
                }
            }
            return self.animationTranslation;
        }
        if (self.localTransform.translation) |t| {
            return zm.translation(t[0], t[1], t[2]);
        }
        return zm.identity();
    }

    fn rotationM(self: *ShapeData) zm.Mat {
        if (self.animationData) |ad| {
            if (ad.get(self.currentFrame())) |sa| {
                if (self.animate) {
                    if (sa.rotation) |r| {
                        self.animationRotation = zm.matFromQuat(r);
                    }
                }
            }
            return self.animationRotation;
        }
        if (self.localTransform.rotation) |r| {
            return zm.matFromQuat(r);
        }
        return zm.identity();
    }

    fn scaleM(self: *ShapeData) zm.Mat {
        if (self.localTransform.scale) |s| {
            return zm.scaling(s[0], s[1], s[2]);
        }
        return zm.identity();
    }

    fn transform(self: *ShapeData) zm.Mat {
        var m = zm.identity();
        if (self.localTransform.parent) |p| {
            m = zm.mul(m, p.scaleM());
            m = zm.mul(m, self.scaleM());
            m = zm.mul(m, p.rotationM());
            m = zm.mul(m, self.rotationM());
            m = zm.mul(m, p.translationM());
            return zm.mul(m, self.translationM());
        }
        m = zm.mul(m, self.scaleM());
        m = zm.mul(m, self.rotationM());
        return zm.mul(m, self.translationM());
    }
};

pub const MeshData = struct {
    meshId: u32,
    vao: gl.Uint,
    vbo: gl.Uint,
    ebo: gl.Uint,
    texture: gl.Uint,
    numIndices: gl.Int,
    mobShapeData: *ShapeData,
    alloc: std.mem.Allocator,
    pub fn init(
        meshId: u32,
        mobShapeData: *ShapeData,
        alloc: std.mem.Allocator,
    ) !MeshData {
        const vao = try gfx.Gfx.initVAO();
        const vbo = try gfx.Gfx.initVBO();
        const ebo = try gfx.Gfx.initEBO(mobShapeData.indices.items);
        var texture: gl.Uint = 0;
        if (mobShapeData.textureData) |td| {
            texture = try initTexture(meshId, td);
        } else {
            texture = try initClearTexture(meshId);
        }
        try initData(meshId, mobShapeData, alloc);
        return MeshData{
            .meshId = meshId,
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
            .texture = texture,
            .numIndices = @intCast(mobShapeData.indices.items.len),
            .mobShapeData = mobShapeData,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: MeshData) void {
        gl.deleteVertexArrays(1, &self.vao);
        gl.deleteBuffers(1, &self.vbo);
        gl.deleteBuffers(1, &self.ebo);
        var mmd = self.mobShapeData;
        mmd.deinit();
        self.alloc.destroy(self.mobShapeData);
        return;
    }

    pub fn initClearTexture(_: u32) !gl.Uint {
        var texture: gl.Uint = undefined;
        var e: gl.Uint = 0;
        gl.genTextures(1, &texture);
        gl.bindTexture(gl.TEXTURE_2D, texture);
        if (e != gl.NO_ERROR) {
            std.debug.print("mobshape clear gen or bind clear texture error: {d}\n", .{e});
            return ShapeErr.RenderError;
        }

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mobshape clear text parameter i error: {d}\n", .{e});
            return ShapeErr.RenderError;
        }

        const imageData: [4]u8 = .{ 0, 0, 0, 0 };
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, &imageData);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mobshape clear text image 2d error: {d}\n", .{e});
            return ShapeErr.RenderError;
        }
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mobshape clear generate mimap error: {d}\n", .{e});
            return ShapeErr.RenderError;
        }
        return texture;
    }

    pub fn initTexture(_: u32, img: []u8) !gl.Uint {
        var texture: gl.Uint = undefined;
        var e: gl.Uint = 0;
        gl.genTextures(1, &texture);
        gl.bindTexture(gl.TEXTURE_2D, texture);
        if (e != gl.NO_ERROR) {
            std.debug.print("mob shape texture gen or bind texture error: {d}\n", .{e});
            return ShapeErr.RenderError;
        }

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST_MIPMAP_NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mob shape texture text parameter i error: {d}\n", .{e});
            return ShapeErr.RenderError;
        }

        var image = try zstbi.Image.loadFromMemory(img, 4);
        defer image.deinit();

        const width: gl.Int = @as(gl.Int, @intCast(image.width));
        const height: gl.Int = @as(gl.Int, @intCast(image.height));
        const imageData: *const anyopaque = image.data.ptr;
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, imageData);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mob shape texture gext image 2d error: {d}\n", .{e});
            return ShapeErr.RenderError;
        }
        gl.generateMipmap(gl.TEXTURE_2D);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mob shape texture generate mimap error: {d}\n", .{e});
            return ShapeErr.RenderError;
        }
        return texture;
    }

    fn initData(meshId: u32, mobShapeData: *ShapeData, alloc: std.mem.Allocator) !void {
        var vertices = try std.ArrayList(ShapeVertex).initCapacity(alloc, mobShapeData.positions.items.len);
        defer vertices.deinit();

        for (0..mobShapeData.positions.items.len) |i| {
            const vtx = ShapeVertex{
                .position = mobShapeData.positions.items[i],
                .normals = mobShapeData.normals.items[i],
                .textcoords = mobShapeData.textcoords.items[i],
                .baseColor = mobShapeData.baseColor,
            };
            vertices.appendAssumeCapacity(vtx);
        }
        const size = @as(isize, @intCast(vertices.items.len * @sizeOf(ShapeVertex)));
        const dataptr: *const anyopaque = vertices.items.ptr;
        gl.bufferData(gl.ARRAY_BUFFER, size, dataptr, gl.STATIC_DRAW);
        const posSize: gl.Int = 3;
        const normalSize: gl.Int = 3;
        const textcoordSize: gl.Int = 2;
        const baseColorSize: gl.Int = 4;
        var stride: gl.Int = 0;
        stride += posSize;
        stride += normalSize;
        stride += textcoordSize;
        stride += baseColorSize;
        var offset: gl.Uint = 0;
        var curArr: gl.Uint = 0;
        gl.vertexAttribPointer(curArr, posSize, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), null);
        gl.enableVertexAttribArray(curArr);
        curArr += 1;
        offset += posSize;
        gl.vertexAttribPointer(curArr, normalSize, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), @as(*anyopaque, @ptrFromInt(offset * @sizeOf(gl.Float))));
        gl.enableVertexAttribArray(curArr);
        curArr += 1;
        offset += normalSize;
        gl.vertexAttribPointer(curArr, textcoordSize, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), @as(*anyopaque, @ptrFromInt(offset * @sizeOf(gl.Float))));
        gl.enableVertexAttribArray(curArr);
        curArr += 1;
        offset += textcoordSize;
        gl.vertexAttribPointer(curArr, baseColorSize, gl.FLOAT, gl.FALSE, stride * @sizeOf(gl.Float), @as(*anyopaque, @ptrFromInt(offset * @sizeOf(gl.Float))));
        gl.enableVertexAttribArray(curArr);

        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} mob init data error: {d}\n", .{ meshId, e });
            return ShapeErr.RenderError;
        }
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    }

    pub fn draw(self: *MeshData, program: gl.Uint) !void {
        gl.bindVertexArray(self.vao);
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} mob draw bind vertex array error: {d}\n", .{ self.meshId, e });
            return ShapeErr.RenderError;
        }

        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, self.texture);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} mob draw bind texture error: {d}\n", .{ self.meshId, e });
            return ShapeErr.RenderError;
        }

        const location = gl.getUniformLocation(program, "meshMatrices");
        const mr = zm.matToArr(self.mobShapeData.transform());
        const im = zm.matToArr(zm.identity());
        var toModelSpace: [32]gl.Float = [_]gl.Float{0} ** 32;
        @memcpy(toModelSpace[0..16], &mr);
        @memcpy(toModelSpace[16..32], &im);
        gl.uniformMatrix4fv(location, 2, gl.FALSE, &toModelSpace);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("error: {d}\n", .{e});
            return ShapeErr.RenderError;
        }

        gl.drawElements(gl.TRIANGLES, self.numIndices, gl.UNSIGNED_INT, null);
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} mob draw draw elements error: {d}\n", .{ self.meshId, e });
            return ShapeErr.RenderError;
        }
    }
};

pub const Shape = struct {
    mobId: i32,
    program: gl.Uint,
    mobMeshData: std.AutoHashMap(u32, MeshData),
    alloc: std.mem.Allocator,

    pub fn init(
        vm: view.View,
        mobId: i32,
        vertexShaderSource: [:0]const u8,
        fragmentShaderSource: [:0]const u8,
        alloc: std.mem.Allocator,
    ) !Shape {
        const vertexShader = try initVertexShader(mobId, vertexShaderSource);
        const fragmentShader = try initFragmentShader(mobId, fragmentShaderSource);
        const program = try initProgram(mobId, &[_]gl.Uint{ vertexShader, fragmentShader });
        try setUniforms(mobId, program, vm);
        return Shape{
            .mobId = mobId,
            .program = program,
            .mobMeshData = std.AutoHashMap(u32, MeshData).init(alloc),
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Shape) void {
        gl.deleteProgram(self.program);
        var meshIterator = self.mobMeshData.keyIterator();
        while (meshIterator.next()) |_k| {
            if (@TypeOf(_k) == *u32) {
                const meshId = _k.*;
                var mesh = self.mobMeshData.get(meshId).?;
                mesh.deinit();
            } else {
                @panic("invalid mesh key");
            }
        }
        var mmd = &self.mobMeshData;
        mmd.deinit();
        return;
    }

    pub fn addMeshData(
        self: *Shape,
        meshId: u32,
        mobShapeData: *ShapeData,
    ) !void {
        gl.useProgram(self.program);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mob id {d} mesh id {d} mob addMeshData error: {d}\n", .{ self.mobId, meshId, e });
            return ShapeErr.RenderError;
        }
        var vd = try MeshData.init(meshId, mobShapeData, self.alloc);
        _ = &vd;
        try self.mobMeshData.put(meshId, vd);
        return;
    }

    pub fn clear(self: *Shape) void {
        for (self.mobMeshData.items) |vs| {
            vs.deinit();
        }
        self.mobMeshData.clearRetainingCapacity();
    }

    pub fn initVertexShader(mobId: i32, vertexShaderSource: [:0]const u8) !gl.Uint {
        var buffer: [100]u8 = undefined;
        const shaderMsg = try std.fmt.bufPrint(&buffer, "{d}: VERTEX", .{mobId});
        return initShader(shaderMsg, vertexShaderSource, gl.VERTEX_SHADER);
    }

    pub fn initFragmentShader(mobId: i32, fragmentShaderSource: [:0]const u8) !gl.Uint {
        var buffer: [100]u8 = undefined;
        const shaderMsg = try std.fmt.bufPrint(&buffer, "{d}: FRAGMENT", .{mobId});
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
            return ShapeErr.RenderError;
        }

        return shader;
    }

    pub fn initProgram(mobId: i32, shaders: []const gl.Uint) !gl.Uint {
        const shaderProgram: gl.Uint = gl.createProgram();
        for (shaders) |shader| {
            gl.attachShader(shaderProgram, shader);
        }
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("init mob program {d} error: {d}\n", .{ mobId, e });
            return ShapeErr.RenderError;
        }

        gl.linkProgram(shaderProgram);
        var success: gl.Int = 0;
        gl.getProgramiv(shaderProgram, gl.LINK_STATUS, &success);
        if (success == 0) {
            var infoLog: [512]u8 = undefined;
            var logSize: gl.Int = 0;
            gl.getProgramInfoLog(shaderProgram, 512, &logSize, &infoLog);
            const i: usize = @intCast(logSize);
            std.debug.print("ERROR::SHADER::{d}::PROGRAM::LINKING_FAILED\n{s}\n", .{ mobId, infoLog[0..i] });
            return ShapeErr.RenderError;
        }

        for (shaders) |shader| {
            gl.deleteShader(shader);
        }

        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} mob error: {d}\n", .{ mobId, e });
            return ShapeErr.RenderError;
        }
        return shaderProgram;
    }

    pub fn setUniforms(mobId: i32, program: gl.Uint, vm: view.View) !void {
        gl.useProgram(program);
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} mob set uniforms error: {d}\n", .{ mobId, e });
            return ShapeErr.RenderError;
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
            return ShapeErr.RenderError;
        }

        const blockIndex: gl.Uint = gl.getUniformBlockIndex(program, vm.name.ptr);
        const bindingPoint: gl.Uint = 1;
        gl.uniformBlockBinding(program, blockIndex, bindingPoint);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mob error mobId: {d} - {d}\n", .{ mobId, e });
            return ShapeErr.RenderError;
        }
        gl.bindBufferBase(gl.UNIFORM_BUFFER, bindingPoint, vm.ubo);
    }

    pub fn draw(self: Shape) !void {
        gl.useProgram(self.program);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} mob draw error: {d}\n", .{ self.mobId, e });
            return ShapeErr.RenderError;
        }

        var meshIterator = self.mobMeshData.keyIterator();
        while (meshIterator.next()) |_k| {
            if (@TypeOf(_k) == *u32) {
                const meshId = _k.*;
                var mesh = self.mobMeshData.get(meshId).?;
                try mesh.draw(self.program);
            } else {
                @panic("invalid mesh key");
            }
        }
    }
};
