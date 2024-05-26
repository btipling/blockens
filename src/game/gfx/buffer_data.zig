pub const AttributeBuilder = struct {
    vbo: u32 = 0,
    stride: gl.Sizei = 0, // The size of each vertexes attribute variable bufferXS
    buffer: []u8 = undefined,
    usage: gl.Enum,
    num_vertices: u32 = 0,
    attr_vars: std.ArrayListUnmanaged(AttributeVariable) = undefined,
    cur_vertex: usize = 0,
    debug: bool = false,
    starting_location: u32 = 0,
    last_location: u32 = 0,

    const AttributeVariable = struct {
        type: gl.Enum,
        size: i32,
        location: u32 = 0,
        offset: usize,
        normalized: gl.Boolean = gl.FALSE,
        divisor: bool = false,
    };

    pub fn init(
        num_vertices: u32,
        vbo: u32,
        usage: gl.Enum,
    ) AttributeBuilder {
        return AttributeBuilder{
            .vbo = vbo,
            .usage = usage,
            .num_vertices = num_vertices,
            .attr_vars = std.ArrayListUnmanaged(AttributeVariable){},
        };
    }

    pub fn initWithLoc(
        num_vertices: u32,
        vbo: u32,
        usage: gl.Enum,
        location: u32,
    ) AttributeBuilder {
        return AttributeBuilder{
            .vbo = vbo,
            .usage = usage,
            .num_vertices = num_vertices,
            .attr_vars = std.ArrayListUnmanaged(AttributeVariable){},
            .starting_location = location,
            .last_location = location,
        };
    }

    pub fn deinit(self: *AttributeBuilder) void {
        self.attr_vars.deinit(game.state.allocator);
        game.state.allocator.free(self.buffer);
        game.state.allocator.destroy(self);
    }

    pub fn get_location(self: AttributeBuilder) u32 {
        return self.last_location;
    }

    fn sizeFromType(t: gl.Enum) usize {
        return switch (t) {
            gl.FLOAT => @sizeOf(f32),
            gl.UNSIGNED_INT => @sizeOf(u32),
            else => @panic("currently unsupported vertex attribute variable"),
        };
    }

    pub fn defineFloatAttributeValue(self: *AttributeBuilder, size: i32) u32 {
        return self.defineFloatAttributeValueWithDivisor(size, false);
    }

    pub fn defineFloatAttributeValueWithDivisor(self: *AttributeBuilder, size: i32, divisor: bool) u32 {
        var offset: usize = 0;
        for (self.attr_vars.items) |av| {
            offset += @as(usize, @intCast(av.size)) * sizeFromType(av.type);
        }
        const av: AttributeVariable = .{
            .type = gl.FLOAT,
            .size = size,
            .location = self.last_location,
            .normalized = gl.FALSE,
            .offset = offset,
            .divisor = divisor,
        };
        self.last_location += 1;
        self.stride += @as(gl.Sizei, @intCast(av.size)) * @as(gl.Sizei, @intCast(sizeFromType(av.type)));
        self.attr_vars.append(game.state.allocator, av) catch @panic("OOM");
        if (self.debug) std.debug.print("defined float attribute value: \n", .{});
        if (self.debug) std.debug.print("   - size: {d} \n", .{av.size});
        if (self.debug) std.debug.print("   - offset: {d} \n", .{av.offset});
        if (self.debug) std.debug.print("   - location: {d} \n\n", .{av.location});
        return av.location;
    }

    pub fn defineUintAttributeValue(self: *AttributeBuilder, size: i32) u32 {
        return self.defineUintAttributeValueWithDivisor(size, false);
    }

    pub fn defineUintAttributeValueWithDivisor(self: *AttributeBuilder, size: i32, divisor: bool) u32 {
        var offset: usize = 0;
        for (self.attr_vars.items) |av| {
            offset += @as(usize, @intCast(av.size)) * sizeFromType(av.type);
        }
        const av: AttributeVariable = .{
            .type = gl.UNSIGNED_INT,
            .size = size,
            .location = self.last_location,
            .normalized = gl.FALSE,
            .offset = offset,
            .divisor = divisor,
        };
        self.last_location += 1;
        self.stride += @as(gl.Sizei, @intCast(av.size)) * @as(gl.Sizei, @intCast(sizeFromType(av.type)));
        self.attr_vars.append(game.state.allocator, av) catch @panic("OOM");
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
        self.buffer = game.state.allocator.alloc(u8, s) catch @panic("OOM");
    }

    pub fn nextVertex(self: *AttributeBuilder) void {
        self.cur_vertex += 1;
        if (self.cur_vertex > self.num_vertices) {
            @panic("vertex overflow");
        }
    }

    pub fn addFloatAtLocation(
        self: *AttributeBuilder,
        location: u32,
        data: []const f32,
        vertex_index: usize,
    ) void {
        const av = self.attr_vars.items[location - self.starting_location];
        const dataptr: []const u8 = std.mem.sliceAsBytes(data);
        if (self.debug) {
            std.debug.print("dataptr len: {d}\n", .{dataptr.len});
            for (dataptr) |b| {
                std.debug.print("{d} ", .{b});
            }
            std.debug.print("\n", .{});
        }
        const stride: usize = @intCast(self.stride);
        const start = stride * vertex_index + av.offset;
        if (self.debug) {
            std.debug.print("addFloatAtLocation - loc: {d}, vertex: {d} av.offset: {d} \n", .{
                location,
                vertex_index,
                av.offset,
            });
            for (0..dataptr.len) |i| {
                const buf_i = start + i;
                if (self.debug) std.debug.print(" {d} ,", .{buf_i});
                self.buffer[buf_i] = dataptr[i];
            }
            std.debug.print("\n", .{});
        } else {
            for (0..dataptr.len) |i| self.buffer[start + i] = dataptr[i];
        }
    }

    pub fn addUintAtLocation(
        self: *AttributeBuilder,
        location: u32,
        data: []const u32,
        vertex_index: usize,
    ) void {
        const av = self.attr_vars.items[location - self.starting_location];
        const dataptr: []const u8 = std.mem.sliceAsBytes(data);
        if (self.debug) {
            std.debug.print("dataptr len: {d}\n", .{dataptr.len});
            for (dataptr) |b| {
                std.debug.print("{d} ", .{b});
            }
            std.debug.print("\n", .{});
        }
        const stride: usize = @intCast(self.stride);
        const start = stride * vertex_index + av.offset;
        if (self.debug) {
            std.debug.print("addUintAtLocation - loc: {d}, vertex: {d} av.offset: {d} \n", .{
                location,
                vertex_index,
                av.offset,
            });
            for (0..dataptr.len) |i| {
                const buf_i = start + i;
                if (self.debug) std.debug.print(" {d} ,", .{buf_i});
                self.buffer[buf_i] = dataptr[i];
            }
            std.debug.print("\n", .{});
        } else {
            for (0..dataptr.len) |i| self.buffer[start + i] = dataptr[i];
        }
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

const std = @import("std");
const gl = @import("zopengl").bindings;
const game = @import("../game.zig");
