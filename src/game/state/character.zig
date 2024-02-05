const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const state = @import("state.zig");
const shapeview = @import("../shape/view.zig");
const mobMesh = @import("../shape/mob_mesh.zig");

pub const Character = struct {
    alloc: std.mem.Allocator,
    shapeview: shapeview.View,
    wireframe: bool = false,
    mob: ?mobMesh.MobMesh,
    xRot: gl.Float,
    yRot: gl.Float,
    zRot: gl.Float,
    pub fn init(
        alloc: std.mem.Allocator,
    ) !Character {
        const xRot: gl.Float = 0.25;
        const yRot: gl.Float = 1;
        const zRot: gl.Float = 1;
        const vm = try shapeview.View.init(zm.identity());
        var c = Character{
            .alloc = alloc,
            .shapeview = vm,
            .mob = null,
            .xRot = xRot,
            .yRot = yRot,
            .zRot = zRot,
        };
        try updateView(&c);
        return c;
    }

    fn updateView(self: *Character) !void {
        var m = zm.identity();
        m = zm.mul(m, zm.scaling(0.05, 0.05, 0.05));
        m = zm.mul(m, zm.rotationX(self.xRot * std.math.pi * 2.0));
        m = zm.mul(m, zm.rotationY(self.yRot * std.math.pi * 2.0));
        m = zm.mul(m, zm.rotationZ(self.zRot * std.math.pi * 2.0));
        try self.shapeview.update(zm.mul(m, zm.translation(-0.25, 0.25, -1.0)));
    }

    pub fn deinit(self: Character) void {
        self.clearMob();
    }

    pub fn clearMob(self: Character) void {
        if (self.mob) |_| {
            self.mob.?.deinit();
        }
    }

    pub fn rotateX(self: *Character, amount: gl.Float) !void {
        self.xRot = self.xRot + amount;
        try self.updateView();
    }

    pub fn rotateY(self: *Character, amount: gl.Float) !void {
        self.yRot = self.yRot + amount;
        try self.updateView();
    }

    pub fn rotateZ(self: *Character, amount: gl.Float) !void {
        self.zRot = self.zRot + amount;
        try self.updateView();
    }

    pub fn generate(self: *Character) !void {
        self.clearMob();
        var mob = try mobMesh.MobMesh.init(self.shapeview, 0, self.alloc);
        try mob.build();
        self.mob = mob;
    }

    pub fn clearCharacterViewState(self: *Character) !void {
        self.shapeview.unbind();
    }

    pub fn focusView(self: *Character) !void {
        self.shapeview.bind();
    }
};
