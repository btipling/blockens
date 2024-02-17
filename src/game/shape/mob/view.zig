const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl");

pub const ViewError = error{
    UpdateError,
};

pub const View = struct {
    viewMatrix: zm.Mat,
    ubo: gl.Uint,
    name: []const u8 = "ViewMatrixBlock",
    pub fn init(initial: zm.Mat) !View {
        const ubo = try View.initData(initial);
        return View{
            .viewMatrix = initial,
            .ubo = ubo,
        };
    }

    pub fn initData(data: zm.Mat) !gl.Uint {
        var ubo: gl.Uint = undefined;
        gl.genBuffers(1, &ubo);
        gl.bindBuffer(gl.UNIFORM_BUFFER, ubo);

        var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
        zm.storeMat(&transform, data);
        const size = @as(isize, @intCast(transform.len * @sizeOf(gl.Float)));
        gl.bufferData(gl.UNIFORM_BUFFER, size, &transform, gl.STATIC_DRAW);
        gl.bindBuffer(gl.UNIFORM_BUFFER, 0);
        return ubo;
    }

    pub fn update(self: *View, updated: zm.Mat) !void {
        // std.debug.print("updating view matrix for ubo: {d}\n", .{self.ubo});
        self.viewMatrix = updated;
        gl.bindBuffer(gl.UNIFORM_BUFFER, self.ubo);
        var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
        zm.storeMat(&transform, updated);
        const size = @as(isize, @intCast(transform.len * @sizeOf(gl.Float)));
        gl.bufferSubData(gl.UNIFORM_BUFFER, 0, size, &transform);
        gl.bindBuffer(gl.UNIFORM_BUFFER, 0);
    }

    pub fn bind(self: *View) void {
        gl.bindBuffer(gl.UNIFORM_BUFFER, self.ubo);
    }

    pub fn unbind(_: *View) void {
        gl.bindBuffer(gl.UNIFORM_BUFFER, 0);
    }
};
