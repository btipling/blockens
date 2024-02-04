const std = @import("std");
const zm = @import("zmath");
const state = @import("state.zig");
const shapeview = @import("../shape/view.zig");
const mobMesh = @import("../shape/mob_mesh.zig");

pub const Character = struct {
    alloc: std.mem.Allocator,
    shapeview: shapeview.View,
    wireframe: bool = false,
    mob: ?mobMesh.MobMesh,
    pub fn init(
        alloc: std.mem.Allocator,
    ) !Character {
        var m = zm.identity();
        m = zm.mul(m, zm.rotationX(0.05 * std.math.pi * 2.0));
        m = zm.mul(m, zm.rotationZ(-0.05 * std.math.pi * 2.0));
        m = zm.mul(m, zm.rotationY(-0.2 * std.math.pi * 2.0));
        m = zm.mul(m, zm.scaling(0.05, 0.05, 0.05));
        m = zm.mul(m, zm.translation(-0.25, 0.0, -1.0));
        const vm = try shapeview.View.init(m);
        return Character{
            .alloc = alloc,
            .shapeview = vm,
            .mob = null,
        };
    }

    pub fn deinit(self: Character) void {
        self.clearMob();
    }

    pub fn clearMob(self: Character) void {
        if (self.mob) |_| {
            self.mob.?.deinit();
        }
    }

    pub fn generate(self: *Character) !void {
        self.clearMob();
        var mob = try mobMesh.MobMesh.init(self.shapeview, 0, self.alloc);
        try mob.generate();
        self.mob = mob;
    }

    pub fn clearCharacterViewState(self: *Character) !void {
        self.shapeview.unbind();
    }

    pub fn focusView(self: *Character) !void {
        self.shapeview.bind();
    }
};
