const gl = @import("zopengl");
const ecs = @import("zflecs");
const game = @import("../../../game.zig");
const math = @import("../../../math/math.zig");
pub const texture_gen = @import("components_texture_gen.zig");

pub const Screen = struct {
    current: u64 = 0,
    gameDataEntity: u64 = 0,
    settingDataEntity: u64 = 0,
    ubo: gl.Uint = 0,
    uboBindingPoint: gl.Uint = 0,
};

pub const Camera = struct {
    ubo: gl.Uint = 0,
    elapsedTime: gl.Float = 0,
};
pub const CameraPosition = struct {
    pos: @Vector(4, gl.Float) = undefined,
};
pub const CameraFront = struct {
    front: @Vector(4, gl.Float) = undefined,
};

pub const CameraRotation = struct {
    yaw: gl.Float = 0,
    pitch: gl.Float = 0,
};

pub const UpDirection = struct {
    up: @Vector(4, gl.Float) = undefined,
};

pub const Perspective = struct {
    fovy: gl.Float,
    aspect: gl.Float,
    near: gl.Float,
    far: gl.Float,
};

pub const PostPerspective = struct {
    translation: @Vector(4, gl.Float) = undefined,
};

pub const WorldLocation = struct {
    loc: @Vector(4, gl.Float) = undefined,

    pub fn toVec(self: WorldLocation) math.vecs.Vflx4 {
        return math.vecs.Vflx4.initFloats(
            self.loc[0],
            self.loc[1],
            self.loc[2],
            0,
        );
    }
};

pub const Data = struct {};
pub const Game = struct {};
pub const Cursor = struct {};
pub const Settings = struct {};
pub const Updated = struct {};
pub const NeedsAnimation = struct {};

pub fn init() void {
    ecs.COMPONENT(game.state.world, Screen);

    ecs.COMPONENT(game.state.world, Camera);
    ecs.COMPONENT(game.state.world, CameraPosition);
    ecs.COMPONENT(game.state.world, CameraFront);
    ecs.COMPONENT(game.state.world, CameraRotation);
    ecs.COMPONENT(game.state.world, UpDirection);

    ecs.COMPONENT(game.state.world, Perspective);
    ecs.COMPONENT(game.state.world, PostPerspective);
    ecs.COMPONENT(game.state.world, WorldLocation);

    ecs.TAG(game.state.world, Data);
    ecs.TAG(game.state.world, Game);
    ecs.TAG(game.state.world, Data);
    ecs.TAG(game.state.world, Cursor);
    ecs.TAG(game.state.world, Settings);
    ecs.TAG(game.state.world, Updated);
    ecs.TAG(game.state.world, NeedsAnimation);
    texture_gen.init();
}
