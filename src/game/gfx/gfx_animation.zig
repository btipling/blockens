pub const Animation = struct {
    pub const AnimationKeyFrame = struct {
        frame: f32,
        scale: @Vector(4, f32),
        rotation: @Vector(4, f32),
        translation: @Vector(4, f32),
    };
    animation_id: u32 = 0,
    animation_offset: usize = 0,
    keyframes: ?[]AnimationKeyFrame = null,
    added: bool = false,
};

pub const AnimationData = struct {
    animation_binding_point: u32 = constants.AnimationBindingPoint,
    data: std.AutoHashMap(AnimationRefKey, *Animation) = undefined,
    animations_running: u32 = constants.DemoCubeAnimationID, // Democube animation is always running atm.
    num_frames: usize = 0,

    // AnimationRefKey - outside of the animation_id, these fields are whatever makes sense, creating
    // and using the same key twice will overwrite previous data which is probably an error.
    pub const AnimationRefKey = struct {
        animation_id: u32,
        animation_mesh_id: u8 = 0,
        ref_id: u8 = 0,
    };

    pub fn init(allocator: std.mem.Allocator) AnimationData {
        return .{
            .data = std.AutoHashMap(AnimationRefKey, *Animation).init(allocator),
        };
    }

    pub fn deinit(self: *AnimationData, allocator: std.mem.Allocator) void {
        var it = self.data.iterator();
        while (it.next()) |e| {
            const a: *Animation = e.value_ptr.*;
            if (a.keyframes) |k| allocator.free(k);
            allocator.destroy(a);
        }
        self.data.deinit();
    }

    pub fn add(self: *AnimationData, key: AnimationRefKey, animation: *Animation, ssbos: *std.AutoHashMap(u32, u32)) void {
        var ssbo: u32 = 0;
        var added = false;
        const kf = animation.keyframes orelse return;

        animation.animation_offset = self.num_frames;
        self.data.put(key, animation) catch @panic("OOM");
        self.num_frames += kf.len;

        ssbo = ssbos.get(self.animation_binding_point) orelse blk: {
            added = true;
            const new_ssbo = gl.animation_buffer.initAnimationShaderStorageBufferObject(
                self.animation_binding_point,
                kf,
            );
            ssbos.put(self.animation_binding_point, new_ssbo) catch @panic("OOM");
            break :blk new_ssbo;
        };
        if (!added) {
            gl.animation_buffer.resizeAnimationShaderStorageBufferObject(ssbo, self.num_frames);
            var it = self.data.iterator();
            while (it.next()) |e| {
                const ani: *Animation = e.value_ptr.*;
                const akf = ani.keyframes orelse continue;
                gl.animation_buffer.addAnimationShaderStorageBufferData(ssbo, ani.animation_offset, akf);
            }
        }
    }
};

const std = @import("std");
pub const gl = @import("gl.zig");
pub const constants = @import("gfx_constants.zig");
