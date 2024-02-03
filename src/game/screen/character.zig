const state = @import("../state/state.zig");
const gl = @import("zopengl");

pub const Character = struct {
    character: *state.character.Character,

    pub fn init(character: *state.character.Character) !Character {
        return Character{
            .character = character,
        };
    }

    pub fn deinit(character: Character) void {
        _ = character;
    }

    pub fn draw(self: *Character) !void {
        if (self.character.wireframe) {
            gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
        }

        if (self.character.wireframe) {
            gl.polygonMode(gl.FRONT_AND_BACK, gl.FILL);
        }
    }
};
