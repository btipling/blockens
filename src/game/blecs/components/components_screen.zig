const gl = @import("zopengl");
const ecs = @import("zflecs");
const game = @import("../../game.zig");
const math = @import("../../math/math.zig");

pub const Screen = struct {
    current: u64 = 0,
    gameDataEntity: u64 = 0,
    settingDataEntity: u64 = 0,
    ubo: gl.Uint = 0,
    uboBindingPoint: gl.Uint = 0,
};

pub const Camera = struct {};
pub const EyePosition = struct {
    x: gl.Float = 0,
    y: gl.Float = 0,
    z: gl.Float = 0,

    pub fn toVec(self: EyePosition) math.vecs.Vflx4 {
        return math.vecs.Vflx4.initFloats(
            self.x,
            self.y,
            self.z,
            0,
        );
    }
};
pub const EyeDirection = struct {
    x: gl.Float = 0,
    y: gl.Float = 0,
    z: gl.Float = 0,

    pub fn toVec(self: EyeDirection) math.vecs.Vflx4 {
        return math.vecs.Vflx4.initFloats(
            self.x,
            self.y,
            self.z,
            0,
        );
    }
};
pub const UpDirection = struct {
    x: gl.Float = 0,
    y: gl.Float = 0,
    z: gl.Float = 0,

    pub fn toVec(self: UpDirection) math.vecs.Vflx4 {
        return math.vecs.Vflx4.initFloats(
            self.x,
            self.y,
            self.z,
            0,
        );
    }
};

pub const Perspective = struct {
    fovy: gl.Float,
    aspect: gl.Float,
    near: gl.Float,
    far: gl.Float,
};

pub const WorldLocation = struct {
    x: gl.Float = 0,
    y: gl.Float = 0,
    z: gl.Float = 0,

    pub fn toVec(self: WorldLocation) math.vecs.Vflx4 {
        return math.vecs.Vflx4.initFloats(
            self.x,
            self.y,
            self.z,
            0,
        );
    }
};

pub const Data = struct {};
pub const Game = struct {};
pub const Settings = struct {};

pub fn init() void {
    ecs.COMPONENT(game.state.world, Screen);

    ecs.TAG(game.state.world, Camera);
    ecs.COMPONENT(game.state.world, EyePosition);
    ecs.COMPONENT(game.state.world, EyeDirection);
    ecs.COMPONENT(game.state.world, UpDirection);

    ecs.COMPONENT(game.state.world, Perspective);
    ecs.COMPONENT(game.state.world, WorldLocation);

    ecs.TAG(game.state.world, Data);
    ecs.TAG(game.state.world, Game);
    ecs.TAG(game.state.world, Settings);
}
