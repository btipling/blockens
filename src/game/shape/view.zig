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
        // print each row
        for (0..16) |i| {
            std.debug.print("{d} ", .{transform[i]});
            if (@mod(i, 4) == 3) {
                std.debug.print("\n", .{});
            }
        }
        const size = @as(isize, @intCast(transform.len * @sizeOf(gl.Float)));
        gl.bufferData(gl.UNIFORM_BUFFER, size, &transform, gl.STATIC_DRAW);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("view matrix: bind vbo buff error:  {d}\n", .{e});
            return ViewError.UpdateError;
        }
        return ubo;
    }

    pub fn update(self: *View, updated: zm.Mat) !void {
        self.viewMatrix = updated;
        gl.bindBuffer(gl.UNIFORM_BUFFER, self.ubo);
        var transform: [16]gl.Float = [_]gl.Float{undefined} ** 16;
        zm.storeMat(&transform, updated);
        const size = @as(isize, @intCast(transform.len * @sizeOf(gl.Float)));
        gl.bufferSubData(gl.UNIFORM_BUFFER, 0, size, &transform);
        const e = gl.getError();
        if (e != gl.NO_ERROR) {
            std.debug.print("view matrix: bufferSubData vbo buff error:  {d}\n", .{e});
            return ViewError.UpdateError;
        }
    }
};
