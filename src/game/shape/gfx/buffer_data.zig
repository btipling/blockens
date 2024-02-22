const std = @import("std");
const gl = @import("zopengl");
const game = @import("../../game.zig");

pub const AttributeBuilder = struct {
    vbo: gl.Uint = 0,
    stride: gl.Sizei = 0, // The size of each vertexes attribute variable bufferXS
    buffer: []u8 = undefined,
    usage: gl.Enum,
    num_vertices: gl.Uint = 0,
    attr_vars: std.ArrayListUnmanaged(AttributeVariable) = undefined,
    cur_vertex: usize = 0,

    const AttributeVariable = struct {
        type: gl.Enum,
        size: gl.Int,
        location: gl.Uint = 0,
        pointer: ?*const anyopaque,
        normalized: gl.Boolean = gl.FALSE,
    };

    pub fn init(
        num_vertices: gl.Uint,
        vbo: gl.Uint,
        usage: gl.Enum,
    ) AttributeBuilder {
        return AttributeBuilder{
            .vbo = vbo,
            .usage = usage,
            .num_vertices = num_vertices,
            .attr_vars = std.ArrayListUnmanaged(AttributeVariable){},
        };
    }

    pub fn deinit(self: *AttributeBuilder) void {
        self.attr_vars.deinit(game.state.allocator);
        game.state.allocator.free(self.buffer);
    }

    fn sizeFromType(t: gl.Enum) usize {
        return switch (t) {
            gl.FLOAT => @sizeOf(gl.Float),
            gl.UNSIGNED_INT => @sizeOf(gl.Uint),
            gl.INT => @sizeOf(gl.Int),
            gl.DOUBLE => @sizeOf(gl.Double),
            else => @panic("currently unsupported vertex attribute variable"),
        };
    }

    pub fn defineAttributeValue(self: *AttributeBuilder, t: gl.Enum, size: gl.Int) gl.Uint {
        var pointer: ?*const anyopaque = null;
        var offset: usize = 0;
        for (self.attr_vars.items) |av| {
            offset += @as(usize, @intCast(av.size)) * sizeFromType(av.type);
        }
        if (offset > 0) {
            pointer = @as(*anyopaque, @ptrFromInt(offset));
        }
        const av: AttributeVariable = .{
            .type = t,
            .size = size,
            .location = @intCast(self.attr_vars.items.len),
            .normalized = gl.FALSE,
            .pointer = pointer,
        };
        self.stride += @as(gl.Sizei, @intCast(av.size)) * @as(gl.Sizei, @intCast(sizeFromType(av.type)));
        self.attr_vars.append(game.state.allocator, av) catch unreachable;
        return av.location;
    }

    pub fn initBuffer(self: *AttributeBuilder) void {
        const s = @as(usize, @intCast(self.stride)) * @as(usize, @intCast(self.num_vertices));
        self.buffer = game.state.allocator.alloc(u8, s) catch unreachable;
    }

    pub fn nextVertex(self: *AttributeBuilder) void {
        self.cur_vertex += 1;
        if (self.cur_vertex > self.num_vertices) {
            @panic("vertex overflow");
        }
    }

    // addVertexDataAtLocation - use is responsible for making sure `data` parameter size matches its defineAttributeValue
    pub fn addVertexDataAtLocation(self: *AttributeBuilder, comptime T: type, location: gl.Uint, data: []T) void {
        var buffer_offset = self.cur_vertex * @as(usize, @intCast(self.stride));
        const l: usize = @intCast(location);
        if (l >= self.attr_vars.items.len) {
            @panic("invalid location specified");
        }
        for (0..l) |i| {
            const av = self.attr_vars.items[i];
            buffer_offset += @as(usize, @intCast(av.size)) * sizeFromType(av.type);
        }
        if (buffer_offset > @as(usize, @intCast(self.stride)) * @as(usize, @intCast(self.num_vertices))) {
            @panic("vertex buffer overflow");
        }
        if (sizeFromType(self.attr_vars.items[l].type) != @sizeOf(T)) {
            @panic("type sizes as specified do not match");
        }
        const b: [*]u8 = @as([*]u8, @ptrCast(self.buffer)) + buffer_offset;
        switch (T) {
            gl.Float => {
                const aligned: *align(8) []u8 = @alignCast(@ptrCast(data));
                @memcpy(b, @as([]u8, aligned.*));
            },
            else => @panic("unsupported data type"),
        }
    }

    pub fn write(self: *AttributeBuilder) void {
        gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
        const dataptr: ?*const anyopaque = @ptrCast(self.buffer);
        const s: gl.Sizeiptr = @as(gl.Sizeiptr, @intCast(self.stride)) * @as(gl.Sizeiptr, @intCast(self.num_vertices));
        gl.bufferData(gl.ARRAY_BUFFER, s, dataptr, self.usage);
        for (self.attr_vars.items) |av| {
            gl.vertexAttribPointer(av.location, av.size, av.type, av.normalized, self.stride, av.pointer);
            gl.enableVertexAttribArray(av.location);
        }
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    }
};
