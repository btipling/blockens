const std = @import("std");
const zmesh = @import("zmesh");
const gl = @import("zopengl").bindings;
const zm = @import("zmath");
const gltf = zmesh.io.zcgltf;
const game = @import("../../game.zig");

pub const SamplerErr = error{
    MissingDataErr,
    UnsupportedErr,
    InvalidErr,
};

pub const Sampler = struct {
    node: *gltf.Node,
    name: [*:0]const u8,
    target_path: gltf.AnimationPathType,
    sampler: *gltf.AnimationSampler,
    num_frames: usize = 0,
    rotations: ?[]@Vector(4, gl.Float) = null,
    translations: ?[]@Vector(4, gl.Float) = null,
    frames: ?[]gl.Float = null,

    pub fn init(
        node: *gltf.Node,
        name: [*:0]const u8,
        target_path: gltf.AnimationPathType,
        sampler: *gltf.AnimationSampler,
    ) Sampler {
        return Sampler{
            .node = node,
            .name = name,
            .target_path = target_path,
            .sampler = sampler,
        };
    }

    pub fn deinit(self: *Sampler) void {
        if (self.rotations) |r| game.state.allocator.free(r);
        if (self.translations) |t| game.state.allocator.free(t);
        if (self.frames) |f| game.state.allocator.free(f);
    }

    pub fn build(self: *Sampler) !void {
        const nodeName = self.node.name orelse "no node name";
        try self.buildFrames();
        switch (self.target_path) {
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
        const frames_data = self.sampler.input;
        self.num_frames = frames_data.count;
        switch (frames_data.component_type) {
            .r_32f => {},
            else => {
                std.debug.print("it has invalid component type for input time ", .{});
                return SamplerErr.InvalidErr;
            },
        }

        switch (frames_data.type) {
            .scalar => {},
            else => {
                std.debug.print("invalid time input", .{});
                return SamplerErr.InvalidErr;
            },
        }

        if (frames_data.buffer_view == null) {
            return SamplerErr.MissingDataErr;
        }

        try self.readFramesBuffer(frames_data.buffer_view.?, frames_data.offset);
    }

    fn readFramesBuffer(self: *Sampler, bufferView: *gltf.BufferView, accessorOffset: usize) !void {
        const bufferData = bufferView.buffer.data orelse {
            return SamplerErr.MissingDataErr;
        };
        const dataAddr = @as([*]const u8, @ptrCast(bufferData)) + accessorOffset + bufferView.offset;
        const frames_data = @as([*]const f32, @ptrCast(@alignCast(dataAddr)));
        self.frames = try game.state.allocator.alloc(gl.Float, self.num_frames);
        @memcpy(self.frames.?, frames_data[0..self.num_frames]);
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
        const frames_data = @as([*]const [4]f32, @ptrCast(@alignCast(dataAddr)));
        self.rotations = try game.state.allocator.alloc(@Vector(4, gl.Float), self.num_frames);
        for (0..self.num_frames) |i| {
            self.rotations.?[i] = frames_data[i];
        }
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
        const frames_data = @as([*]const [3]f32, @ptrCast(@alignCast(dataAddr)));
        self.translations = try game.state.allocator.alloc(@Vector(4, gl.Float), self.num_frames);
        for (0..self.num_frames) |i| {
            const f = frames_data[i];
            self.translations.?[i] = .{ f[0], f[1], f[2], 0 };
        }
    }
};
