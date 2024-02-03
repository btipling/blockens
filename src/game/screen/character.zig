const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const mobMesh = @import("../shape/mob_mesh.zig");
const shapeview = @import("../shape/view.zig");
const state = @import("../state/state.zig");

pub const Character = struct {
    character: *state.character.Character,

    pub fn init(
        character: *state.character.Character,
    ) !Character {
        return Character{
            .character = character,
        };
    }

    pub fn deinit(self: Character) void {
        _ = self;
    }

    pub fn draw(self: *Character) !void {
        if (self.character.wireframe) {
            gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
        }

        if (self.character.mob) |_| {
            try self.character.mob.?.draw();
        }

        if (self.character.wireframe) {
            gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
        }
    }
};
