const std = @import("std");
const zmesh = @import("zmesh");
const gl = @import("zopengl").bindings;
const zm = @import("zmath");
const gltf = zmesh.io.zcgltf;

pub const SamplerErr = error{
    MissingDataErr,
    UnsupportedErr,
    InvalidErr,
};

pub const Sampler = struct {
    node: *gltf.Node,
    name: [*:0]const u8,
    targetPath: gltf.AnimationPathType,
    sampler: *gltf.AnimationSampler,
    numFrames: usize = 0,
    rotations: ?[]const [4]gl.Float = null,
    translations: ?[]const [3]gl.Float = null,
    frames: ?[]const gl.Float = null,

    pub fn init(
        node: *gltf.Node,
        name: [*:0]const u8,
        targetPath: gltf.AnimationPathType,
        sampler: *gltf.AnimationSampler,
    ) Sampler {
        return Sampler{
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
                try self.buildTranslation();
            },
            .rotation => {
                try self.buildRotation();
            },
            .scale => {
                std.debug.print("found (unsupported) scale animation node {s} in for {s}\n", .{ nodeName, self.name });
                return SamplerErr.UnsupportedErr;
            },
            .weights => {
                std.debug.print("found (unsupported) weights animation node {s} in for {s}\n", .{ nodeName, self.name });
                return SamplerErr.UnsupportedErr;
            },
            else => {
                std.debug.print("found invalid animation for node {s} in {s}\n", .{ nodeName, self.name });
                return SamplerErr.InvalidErr;
            },
        }
    }

    fn buildFrames(self: *Sampler) !void {
        const framesData = self.sampler.input;
        self.numFrames = framesData.count;
        switch (framesData.component_type) {
            .r_32f => {},
            else => {
                std.debug.print("it has invalid component type for input time ", .{});
                return SamplerErr.InvalidErr;
            },
        }

        switch (framesData.type) {
            .scalar => {},
            else => {
                std.debug.print("invalid time input", .{});
                return SamplerErr.InvalidErr;
            },
        }

        if (framesData.buffer_view == null) {
            return SamplerErr.MissingDataErr;
        }

        try self.readFramesBuffer(framesData.buffer_view.?, framesData.offset);
    }

    fn readFramesBuffer(self: *Sampler, bufferView: *gltf.BufferView, accessorOffset: usize) !void {
        const bufferData = bufferView.buffer.data orelse {
            return SamplerErr.MissingDataErr;
        };
        const dataAddr = @as([*]const u8, @ptrCast(bufferData)) + accessorOffset + bufferView.offset;
        const framesData = @as([*]const f32, @ptrCast(@alignCast(dataAddr)));
        self.frames = framesData[0..self.numFrames];
    }

    pub fn buildRotation(self: *Sampler) !void {
        const rotationData = self.sampler.output;
        switch (rotationData.component_type) {
            .r_32f => {},
            else => {
                std.debug.print("has invalid component type ", .{});
                return SamplerErr.InvalidErr;
            },
        }

        switch (rotationData.type) {
            .vec4 => {},
            else => {
                std.debug.print("and an invalid accessor type\n", .{});
                return SamplerErr.InvalidErr;
            },
        }

        if (rotationData.buffer_view == null) {
            return SamplerErr.MissingDataErr;
        }
        try self.readRotationsBuffer(rotationData.buffer_view.?, rotationData.offset);
    }

    fn readRotationsBuffer(self: *Sampler, bufferView: *gltf.BufferView, accessorOffset: usize) !void {
        const bufferData = bufferView.buffer.data orelse {
            return SamplerErr.MissingDataErr;
        };

        const dataAddr = @as([*]const u8, @ptrCast(bufferData)) + accessorOffset + bufferView.offset;
        const framesData = @as([*]const [4]f32, @ptrCast(@alignCast(dataAddr)));
        self.rotations = framesData[0..self.numFrames];
    }

    pub fn buildTranslation(self: *Sampler) !void {
        const translationData = self.sampler.output;
        switch (translationData.component_type) {
            .r_32f => {},
            else => {
                std.debug.print("has invalid component type ", .{});
                return SamplerErr.InvalidErr;
            },
        }

        switch (translationData.type) {
            .vec3 => {},
            else => {
                std.debug.print("and an invalid accessor type\n", .{});
                return SamplerErr.InvalidErr;
            },
        }
        if (translationData.buffer_view == null) {
            return SamplerErr.MissingDataErr;
        }
        try self.readTranslationBuffer(translationData.buffer_view.?, translationData.offset);
    }

    fn readTranslationBuffer(self: *Sampler, bufferView: *gltf.BufferView, accessorOffset: usize) !void {
        const bufferData = bufferView.buffer.data orelse {
            return SamplerErr.MissingDataErr;
        };
        const dataAddr = @as([*]const u8, @ptrCast(bufferData)) + accessorOffset + bufferView.offset;
        const framesData = @as([*]const [3]f32, @ptrCast(@alignCast(dataAddr)));
        self.translations = framesData[0..self.numFrames];
    }
};
