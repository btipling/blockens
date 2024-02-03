const std = @import("std");
const zm = @import("zmath");
const state = @import("state.zig");
const shapeview = @import("../shape/view.zig");

pub const Character = struct {
    alloc: std.mem.Allocator,
    shapeview: shapeview.View,
    wireframe: bool = false,
    pub fn init(
        alloc: std.mem.Allocator,
    ) !Character {
        var m = zm.identity();
        m = zm.mul(m, zm.scaling(0.25, 0.25, 0.25));
        m = zm.mul(m, zm.translation(-0.25, 0.0, -1.0));
        const vm = try shapeview.View.init(m);
        return Character{
            .alloc = alloc,
            .shapeview = vm,
        };
    }

    pub fn deinit(self: *Character) void {
        _ = self;
    }

    pub fn generate(self: *Character) !void {
        _ = self;
    }

    pub fn clearCharacterViewState(self: *Character) !void {
        self.shapeview.unbind();
    }

    pub fn focusView(self: *Character) !void {
        self.shapeview.bind();
    }
};
