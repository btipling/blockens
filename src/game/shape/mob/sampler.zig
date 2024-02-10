const std = @import("std");
const zmesh = @import("zmesh");
const gl = @import("zopengl");
const zm = @import("zmath");
const gltf = zmesh.io.zcgltf;

pub const SamplerErr = error{
    MissingDataErr,
};

pub const Sampler = struct {
    alloc: std.mem.Allocator,
    node: *gltf.Node,
    name: [*:0]const u8,
    targetPath: gltf.AnimationPathType,
    sampler: *gltf.AnimationSampler,
    numFrames: usize = 0,
    rotations: ?[][4]gl.Float = null,
    translations: ?[][3]gl.Float = null,

    pub fn init(
        alloc: std.mem.Allocator,
        node: *gltf.Node,
        name: [*:0]const u8,
        targetPath: gltf.AnimationPathType,
        sampler: *gltf.AnimationSampler,
    ) Sampler {
        return Sampler{
            .alloc = alloc,
            .node = node,
            .name = name,
            .targetPath = targetPath,
            .sampler = sampler,
        };
    }

    pub fn deinit(_: Sampler) void {}

    pub fn build(self: *Sampler) !void {
        const nodeName = self.node.name orelse "no node name";
        try self.buildFrames();
        switch (self.targetPath) {
            .translation => {
                std.debug.print("found translation animation for node {s} in {s}\n", .{ nodeName, self.name });
                buildAnimationFromTranslationAccessor(self.sampler.output);
            },
            .rotation => {
                std.debug.print("found rotation animation for node {s} in {s}\n", .{ nodeName, self.name });
                buildAnimationFromRotationAccessor(self.sampler.output);
            },
            .scale => {
                std.debug.print("found (unsupported) scale animation node {s} in for {s}\n", .{ nodeName, self.name });
            },
            .weights => {
                std.debug.print("found (unsupported) weights animation node {s} in for {s}\n", .{ nodeName, self.name });
            },
            else => std.debug.print("found invalid animation for node {s} in {s}\n", .{ nodeName, self.name }),
        }
        switch (self.sampler.interpolation) {
            .linear => std.debug.print("found linear interpolation for {s}\n", .{self.name}),
            .step => std.debug.print("found step interpolation for {s}\n", .{self.name}),
            .cubic_spline => std.debug.print("found cubic spline interpolation for {s}\n", .{self.name}),
        }
    }

    fn buildFrames(self: *Sampler) !void {
        const framesData = self.sampler.input;
        self.numFrames = framesData.count;
        std.debug.print("input time has {d} elements, and {d} byte offset with stride of, {d} ", .{
            framesData.count,
            framesData.offset,
            framesData.stride,
        });
        std.debug.print(" is normalized {d}, ", .{framesData.normalized});
        switch (framesData.component_type) {
            .r_32f => std.debug.print("it has r_32f component type ", .{}),
            else => std.debug.print("it has invalid component type for input time ", .{}),
        }

        switch (framesData.type) {
            .scalar => std.debug.print("and scalar type\n", .{}),
            else => std.debug.print("invalid time input", .{}),
        }

        if (framesData.buffer_view == null) {
            return SamplerErr.MissingDataErr;
        }

        try self.readFramesBuffer(framesData.buffer_view.?, framesData.offset);
    }

    fn printBufferViewType(bufferView: *gltf.BufferView) void {
        switch (bufferView.view_type) {
            .invalid => std.debug.print("invalid buffer view type\n", .{}),
            .indices => std.debug.print("buffer view type is indicies\n", .{}),
            .vertices => std.debug.print("buffer view type is vertices\n", .{}),
        }
    }

    fn readFramesBuffer(self: *Sampler, bufferView: *gltf.BufferView, accessorOffset: usize) !void {
        printBufferViewType(bufferView);
        const bufferData = bufferView.buffer.data orelse {
            return SamplerErr.MissingDataErr;
        };
        std.debug.print("buffer view offset: {d}\n", .{bufferView.offset});

        const dataAddr = @as([*]const u8, @ptrCast(bufferData)) + accessorOffset + bufferView.offset;
        const framesData = @as([*]const f32, @ptrCast(@alignCast(dataAddr)));
        for (0..self.numFrames) |i| {
            std.debug.print("found frame with {d} value\n", .{framesData[i]});
        }
    }

    pub fn buildAnimationFromRotationAccessor(acessor: *gltf.Accessor) void {
        const accessorName = acessor.name orelse "no accessor name";
        std.debug.print("rotation {s} has {d} elements, and {d} byte offset with stride of {d}, ", .{
            accessorName,
            acessor.count,
            acessor.offset,
            acessor.stride,
        });
        switch (acessor.component_type) {
            .r_32f => std.debug.print("has r_32f component type ", .{}),
            else => std.debug.print("has invalid component type ", .{}),
        }

        switch (acessor.type) {
            .vec4 => std.debug.print("and vec4 type\n", .{}),
            else => std.debug.print("and an invalid accessor type\n", .{}),
        }
    }

    pub fn buildAnimationFromTranslationAccessor(acessor: *gltf.Accessor) void {
        const accessorName = acessor.name orelse "no accessor name";
        std.debug.print("translation {s} has {d} elements, and {d} byte offset with stride of {d}, ", .{
            accessorName,
            acessor.count,
            acessor.offset,
            acessor.stride,
        });
        switch (acessor.component_type) {
            .r_32f => std.debug.print("has r_32f component type ", .{}),
            else => std.debug.print("has invalid component type ", .{}),
        }

        switch (acessor.type) {
            .vec3 => std.debug.print("and vec3 type\n", .{}),
            else => std.debug.print("and an invalid accessor type\n", .{}),
        }
    }
};
