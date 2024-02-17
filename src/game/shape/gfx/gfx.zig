const std = @import("std");
const gl = @import("zopengl");

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
};
