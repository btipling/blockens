const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const mobMesh = @import("../shape/mob_mesh.zig");
const shapeview = @import("../shape/view.zig");
const state = @import("../state/state.zig");

pub const Character = struct {
    character: *state.character.Character,
    mob: mobMesh.MobMesh,

    pub fn init(
        alloc: std.mem.Allocator,
        character: *state.character.Character,
    ) !Character {
        const mob = try mobMesh.MobMesh.init(character.shapeview, 0, alloc);
        return Character{
            .character = character,
            .mob = mob,
        };
    }

    pub fn deinit(character: Character) void {
        character.mob.deinit();
    }

    pub fn draw(self: *Character) !void {
        if (self.character.wireframe) {
            gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
        }

        try self.mob.draw();

        if (self.character.wireframe) {
            gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
        }
    }
};
