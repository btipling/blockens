const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const state = @import("state.zig");
const shapeview = @import("../shape/mob/view.zig");
const mobMesh = @import("../shape/mob/mesh.zig");

pub const Character = struct {
    alloc: std.mem.Allocator,
    shapeview: shapeview.View,
    wireframe: bool = false,
    mob: ?*mobMesh.Mesh,
    xRot: gl.Float,
    yRot: gl.Float,
    zRot: gl.Float,
    pub fn init(
        alloc: std.mem.Allocator,
    ) !Character {
        const xRot: gl.Float = 0.5;
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
        try self.shapeview.update(zm.mul(m, zm.translation(-0.2, -0.25, -1.0)));
    }

    pub fn worldView(self: *Character) !void {
        var m = zm.identity();
        m = zm.mul(m, zm.scaling(0.025, 0.025, 0.025));
        m = zm.mul(m, zm.rotationX(0.5 * std.math.pi * 2.0));
        m = zm.mul(m, zm.rotationY(0.5 * std.math.pi * 2.0));
        try self.shapeview.update(zm.mul(m, zm.translation(0, -0.5, -1.0)));
    }

    pub fn deinit(self: Character) void {
        self.clearMob();
    }

    pub fn clearMob(self: Character) void {
        if (self.mob) |m| {
            m.deinit();
            self.alloc.destroy(m);
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
        var mob = try mobMesh.Mesh.init(self.shapeview, 0, self.alloc);
        try mob.build();
        const m = try self.alloc.create(mobMesh.Mesh);
        m.* = mob;
        self.mob = m;
    }

    pub fn toggleWalking(self: *Character) !void {
        if (self.mob) |m| {
            @constCast(m).animate = !m.animate;
            self.mob = m;
        }
    }

    pub fn clearCharacterViewState(self: *Character) !void {
        self.shapeview.unbind();
    }

    pub fn focusView(self: *Character) !void {
        try self.updateView();
        self.shapeview.bind();
    }
};
