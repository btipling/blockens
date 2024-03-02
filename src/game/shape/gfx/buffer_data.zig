const std = @import("std");
const gl = @import("zopengl").bindings;
const game = @import("../../game.zig");

pub const AttributeBuilder = struct {
    vbo: gl.Uint = 0,
    stride: gl.Sizei = 0, // The size of each vertexes attribute variable bufferXS
    buffer: []u8 = undefined,
    usage: gl.Enum,
    num_vertices: gl.Uint = 0,
    attr_vars: std.ArrayListUnmanaged(AttributeVariable) = undefined,
    cur_vertex: usize = 0,
    debug: bool = false,

    const AttributeVariable = struct {
        type: gl.Enum,
        size: gl.Int,
        location: gl.Uint = 0,
        offset: usize,
        normalized: gl.Boolean = gl.FALSE,
        divisor: bool = false,
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
            else => @panic("currently unsupported vertex attribute variable"),
        };
    }

    pub fn definFloatAttributeValue(self: *AttributeBuilder, size: gl.Int) gl.Uint {
        var offset: usize = 0;
        for (self.attr_vars.items) |av| {
            offset += @as(usize, @intCast(av.size)) * sizeFromType(av.type);
        }
        const av: AttributeVariable = .{
            .type = gl.FLOAT,
            .size = size,
            .location = @intCast(self.attr_vars.items.len),
            .normalized = gl.FALSE,
            .offset = offset,
        };
        self.stride += @as(gl.Sizei, @intCast(av.size)) * @as(gl.Sizei, @intCast(sizeFromType(av.type)));
        self.attr_vars.append(game.state.allocator, av) catch unreachable;
        if (self.debug) std.debug.print("defined float attribute value: \n", .{});
        if (self.debug) std.debug.print("   - size: {d} \n", .{av.size});
        if (self.debug) std.debug.print("   - offset: {d} \n", .{av.offset});
        if (self.debug) std.debug.print("   - location: {d} \n\n", .{av.location});
        return av.location;
    }

    pub fn initBuffer(self: *AttributeBuilder) void {
        const s = @as(usize, @intCast(self.stride)) * @as(usize, @intCast(self.num_vertices));
        if (self.debug) std.debug.print("init buffer with stride: {d} num vertices: {d} and size: {d}\n\n", .{
            self.stride,
            self.num_vertices,
            s,
        });
        self.buffer = game.state.allocator.alloc(u8, s) catch unreachable;
    }

    pub fn nextVertex(self: *AttributeBuilder) void {
        self.cur_vertex += 1;
        if (self.cur_vertex > self.num_vertices) {
            @panic("vertex overflow");
        }
    }

    pub fn addFloatAtLocation(self: *AttributeBuilder, location: gl.Uint, data: []gl.Float, vertex_index: usize) void {
        const av = self.attr_vars.items[location];
        const dataptr: []const u8 = std.mem.sliceAsBytes(data);
        if (self.debug) std.debug.print("dataptr len: {d}\n", .{dataptr.len});
        for (dataptr) |b| {
            if (self.debug) std.debug.print("{d} ", .{b});
        }
        if (self.debug) std.debug.print("\n", .{});
        const stride: usize = @intCast(self.stride);
        const start = stride * vertex_index + av.offset;
        if (self.debug) std.debug.print("addFloatAtLocation - loc: {d}, vertex: {d} \n", .{ location, vertex_index });
        for (0..dataptr.len) |i| {
            const buf_i = start + i;
            if (self.debug) std.debug.print(" {d} ,", .{buf_i});
            self.buffer[buf_i] = dataptr[i];
        }
        if (self.debug) std.debug.print("\n", .{});
    }

    pub fn write(self: *AttributeBuilder) void {
        gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);

        if (self.debug) std.debug.print("self.buffer len: {d}\n", .{self.buffer.len});
        for (self.buffer) |b| {
            if (self.debug) std.debug.print("{d} ", .{b});
        }
        if (self.debug) std.debug.print("\n", .{});
        const dataptr: ?*const anyopaque = @ptrCast(self.buffer);
        const s: gl.Sizeiptr = @as(gl.Sizeiptr, @intCast(self.stride)) * @as(gl.Sizeiptr, @intCast(self.num_vertices));
        gl.bufferData(gl.ARRAY_BUFFER, s, dataptr, self.usage);
        for (0..self.attr_vars.items.len) |i| {
            const av = self.attr_vars.items[i];
            var pointer: ?*anyopaque = null;
            if (i > 0) {
                pointer = @as(*anyopaque, @ptrFromInt(av.offset));
            }
            if (self.debug) std.debug.print("addVertexAttribute - loc: {d} len: {d} size: {d} stride: {d} \n", .{
                av.location,
                av.size,
                s,
                self.stride,
            });
            gl.vertexAttribPointer(av.location, av.size, av.type, av.normalized, self.stride, pointer);
            gl.enableVertexAttribArray(av.location);
            if (av.divisor) {
                gl.vertexAttribDivisor(av.location, 1);
            }
        }
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    }
};
