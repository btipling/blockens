const std = @import("std");
const gl = @import("zopengl");
const zstbi = @import("zstbi");
const zm = @import("zmath");
const zmesh = @import("zmesh");
const config = @import("../config.zig");
const view = @import("./view.zig");
const data = @import("../data/data.zig");

pub const MobShapeErr = error{
    NotInitialized,
    RenderError,
};

pub const MobShapeVertex = struct {
    position: [3]gl.Float,
    normals: [3]gl.Float,
    textcoords: [2]gl.Float,
    baseColor: [4]gl.Float,
    localTransform: [16]gl.Float,
};

pub const MobShapeData = struct {
    indices: std.ArrayList(u32),
    positions: std.ArrayList([3]gl.Float),
    normals: std.ArrayList([3]gl.Float),
    textcoords: std.ArrayList([2]gl.Float),
    tangents: std.ArrayList([4]gl.Float),
    baseColor: [4]gl.Float,
    localTransform: [16]gl.Float,

    pub fn init(
        alloc: std.mem.Allocator,
        baseColor: [4]gl.Float,
        localTransform: [16]gl.Float,
    ) MobShapeData {
        return .{
            .indices = std.ArrayList(u32).init(alloc),
            .positions = std.ArrayList([3]gl.Float).init(alloc),
            .normals = std.ArrayList([3]gl.Float).init(alloc),
            .textcoords = std.ArrayList([2]gl.Float).init(alloc),
            .tangents = std.ArrayList([4]gl.Float).init(alloc),
            .baseColor = baseColor,
            .localTransform = localTransform,
        };
    }

    pub fn deinit(self: MobShapeData) void {
        self.indices.deinit();
        self.positions.deinit();
        self.normals.deinit();
        self.textcoords.deinit();
        self.tangents.deinit();
    }
};

pub const MobMeshData = struct {
    meshId: u32,
    vao: gl.Uint,
    vbo: gl.Uint,
    ebo: gl.Uint,
    numIndices: gl.Int,
    mobShapeData: MobShapeData,
    pub fn init(
        meshId: u32,
        mobShapeData: MobShapeData,
        alloc: std.mem.Allocator,
    ) !MobMeshData {
        std.debug.print("num textcoords: {d} ", .{mobShapeData.textcoords.items.len});
        std.debug.print("num tangents: {d}\n", .{mobShapeData.tangents.items.len});
        const vao = try initVAO(meshId);
        const vbo = try initVBO(meshId);
        const ebo = try initEBO(meshId, mobShapeData.indices.items);
        try initData(meshId, &mobShapeData, alloc);
        return MobMeshData{
            .meshId = meshId,
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
            .numIndices = @intCast(mobShapeData.indices.items.len),
            .mobShapeData = mobShapeData,
        };
    }

    pub fn deinit(self: MobMeshData) void {
        gl.deleteVertexArrays(1, &self.vao);
        gl.deleteBuffers(1, &self.vbo);
        gl.deleteBuffers(1, &self.ebo);
        var mmd = &self.mobShapeData;
        mmd.deinit();
        return;
    }
    pub fn initVAO(meshId: u32) !gl.Uint {
        var VAO: gl.Uint = undefined;
        gl.genVertexArrays(1, &VAO);
        gl.bindVertexArray(VAO);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mob init vao error meshId: {d} - {d}\n", .{ meshId, e });
            return MobShapeErr.RenderError;
        }
        return VAO;
    }

    pub fn initVBO(meshId: u32) !gl.Uint {
        var VBO: gl.Uint = undefined;
        gl.genBuffers(1, &VBO);
        gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mob init vbo error meshId: {d} - {d}\n", .{ meshId, e });
            return MobShapeErr.RenderError;
        }
        return VBO;
    }

    pub fn initEBO(meshId: u32, indices: []const gl.Uint) !gl.Uint {
        var EBO: gl.Uint = undefined;
        gl.genBuffers(1, &EBO);
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mob init ebo error meshId: {d} - {d}\n", .{ meshId, e });
            return MobShapeErr.RenderError;
        }
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mob bind ebo buff error meshId: {d} - {d}\n", .{ meshId, e });
            return MobShapeErr.RenderError;
        }

        const size = @as(isize, @intCast(indices.len * @sizeOf(gl.Uint)));
        const indicesptr: *const anyopaque = indices.ptr;
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, size, indicesptr, gl.STATIC_DRAW);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mob buffer data error meshId: {d} - {d}\n", .{ meshId, e });
            return MobShapeErr.RenderError;
        }
        return EBO;
    }

    fn initData(meshId: u32, mobShapeData: *const MobShapeData, alloc: std.mem.Allocator) !void {
        var vertices = try std.ArrayList(MobShapeVertex).initCapacity(alloc, mobShapeData.positions.items.len);
        defer vertices.deinit();

        for (0..mobShapeData.positions.items.len) |i| {
            const vtx = MobShapeVertex{
                .position = mobShapeData.positions.items[i],
                .normals = mobShapeData.normals.items[i],
                .textcoords = mobShapeData.textcoords.items[i],
                .baseColor = mobShapeData.baseColor,
                .localTransform = mobShapeData.localTransform,
            };
            vertices.appendAssumeCapacity(vtx);
        }
        const size = @as(isize, @intCast(vertices.items.len * @sizeOf(MobShapeVertex)));
        const dataptr: *const anyopaque = vertices.items.ptr;
        gl.bufferData(gl.ARRAY_BUFFER, size, dataptr, gl.STATIC_DRAW);
        const posSize: gl.Int = 3;
        const normalSize: gl.Int = 3;
        const textcoordSize: gl.Int = 2;
        const baseColorSize: gl.Int = 4;
        const localTransformSize: gl.Int = 4;
        const stride: gl.Int = (posSize + normalSize + textcoordSize + baseColorSize + (localTransformSize * 4)) * @sizeOf(gl.Float);
        std.debug.print("stride: {d}\n", .{stride});
        var offset: gl.Uint = 0;
        var curArr: gl.Uint = 0;
        gl.vertexAttribPointer(curArr, posSize, gl.FLOAT, gl.FALSE, stride, null);
        gl.enableVertexAttribArray(curArr);
        curArr += 1;
        offset += posSize * @sizeOf(gl.Float);
        gl.vertexAttribPointer(curArr, normalSize, gl.FLOAT, gl.FALSE, stride, @as(*anyopaque, @ptrFromInt(offset)));
        gl.enableVertexAttribArray(curArr);
        curArr += 1;
        offset += normalSize * @sizeOf(gl.Float);
        gl.vertexAttribPointer(curArr, textcoordSize, gl.FLOAT, gl.FALSE, stride, @as(*anyopaque, @ptrFromInt(offset)));
        gl.enableVertexAttribArray(curArr);
        curArr += 1;
        offset += textcoordSize * @sizeOf(gl.Float);
        std.debug.print("offset: {d}\n", .{offset});
        for (0..4) |_| {
            gl.vertexAttribPointer(curArr, baseColorSize, gl.FLOAT, gl.FALSE, stride, @as(*anyopaque, @ptrFromInt(offset)));
            gl.enableVertexAttribArray(curArr);
            curArr += 1;
            offset += baseColorSize * @sizeOf(gl.Float);
        }
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} mob init data error: {d}\n", .{ meshId, e });
            return MobShapeErr.RenderError;
        }
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    }

    pub fn draw(self: MobMeshData) !void {
        gl.bindVertexArray(self.vao);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} mob draw bind vertex array error: {d}\n", .{ self.meshId, e });
            return MobShapeErr.RenderError;
        }

        gl.drawElements(gl.TRIANGLES, self.numIndices, gl.UNSIGNED_INT, null);
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} mob draw draw elements error: {d}\n", .{ self.meshId, e });
            return MobShapeErr.RenderError;
        }
    }
};

pub const MobShape = struct {
    mobId: i32,
    program: gl.Uint,
    mobMeshData: std.AutoHashMap(u32, MobMeshData),
    alloc: std.mem.Allocator,

    pub fn init(
        vm: view.View,
        mobId: i32,
        vertexShaderSource: [:0]const u8,
        fragmentShaderSource: [:0]const u8,
        alloc: std.mem.Allocator,
    ) !MobShape {
        const vertexShader = try initVertexShader(mobId, vertexShaderSource);
        const fragmentShader = try initFragmentShader(mobId, fragmentShaderSource);
        const program = try initProgram(mobId, &[_]gl.Uint{ vertexShader, fragmentShader });
        try setUniforms(mobId, program, vm);
        return MobShape{
            .mobId = mobId,
            .program = program,
            .mobMeshData = std.AutoHashMap(u32, MobMeshData).init(alloc),
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *MobShape) void {
        gl.deleteProgram(self.program);
        var meshIterator = self.mobMeshData.keyIterator();
        while (meshIterator.next()) |_k| {
            if (@TypeOf(_k) == *u32) {
                const meshId = _k.*;
                var mesh = self.mobMeshData.get(meshId).?;
                var m = &mesh;
                m.deinit();
            } else {
                @panic("invalid mesh key");
            }
        }
        var mmd = &self.mobMeshData;
        mmd.deinit();
        return;
    }

    pub fn addMeshData(
        self: *MobShape,
        meshId: u32,
        mobShapeData: MobShapeData,
    ) !void {
        gl.useProgram(self.program);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mob id {d} mesh id {d} mob addMeshData error: {d}\n", .{ self.mobId, meshId, e });
            return MobShapeErr.RenderError;
        }
        var vd = try MobMeshData.init(meshId, mobShapeData, self.alloc);
        _ = &vd;
        try self.mobMeshData.put(meshId, vd);
        return;
    }

    pub fn clear(self: *MobShape) void {
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
            return MobShapeErr.RenderError;
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
            return MobShapeErr.RenderError;
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
            return MobShapeErr.RenderError;
        }

        for (shaders) |shader| {
            gl.deleteShader(shader);
        }

        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} mob error: {d}\n", .{ mobId, e });
            return MobShapeErr.RenderError;
        }
        return shaderProgram;
    }

    pub fn setUniforms(mobId: i32, program: gl.Uint, vm: view.View) !void {
        gl.useProgram(program);
        var e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} mob set uniforms error: {d}\n", .{ mobId, e });
            return MobShapeErr.RenderError;
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
            return MobShapeErr.RenderError;
        }
        const blockIndex: gl.Uint = gl.getUniformBlockIndex(program, vm.name.ptr);
        const bindingPoint: gl.Uint = 0;
        gl.uniformBlockBinding(program, blockIndex, bindingPoint);
        e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("mob error mobId: {d} - {d}\n", .{ mobId, e });
            return MobShapeErr.RenderError;
        }
        gl.bindBufferBase(gl.UNIFORM_BUFFER, bindingPoint, vm.ubo);
    }

    pub fn draw(self: MobShape) !void {
        gl.useProgram(self.program);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("{d} mob draw error: {d}\n", .{ self.mobId, e });
            return MobShapeErr.RenderError;
        }

        var meshIterator = self.mobMeshData.keyIterator();
        while (meshIterator.next()) |_k| {
            if (@TypeOf(_k) == *u32) {
                const meshId = _k.*;
                var mesh = self.mobMeshData.get(meshId).?;
                var m = &mesh;
                try m.draw();
            } else {
                @panic("invalid mesh key");
            }
        }
    }
};
