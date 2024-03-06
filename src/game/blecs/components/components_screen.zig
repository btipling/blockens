const gl = @import("zopengl").bindings;
const ecs = @import("zflecs");
const game = @import("../../game.zig");
const math = @import("../../math/math.zig");

pub const Mob = struct {
    mob_id: i32 = 0,
};
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

pub const WorldTranslation = struct {
    translation: @Vector(4, gl.Float) = undefined,
};

pub const WorldRotation = struct {
    rotation: @Vector(4, gl.Float) = undefined,
};

pub const WorldScale = struct {
    scale: @Vector(4, gl.Float) = undefined,
};

pub const PostPerspective = struct {
    translation: @Vector(4, gl.Float) = undefined,
};

pub const WorldLocation = struct {
    loc: @Vector(4, gl.Float) = undefined,
};

pub const Data = struct {};
pub const Game = struct {};
pub const Cursor = struct {};
pub const Settings = struct {};
pub const Updated = struct {};
pub const NeedsAnimation = struct {};
pub const NeedsDemoChunk = struct {};

// setting screens
pub const TextureGen = struct {};
pub const BlockEditor = struct {};
pub const ChunkEditor = struct {};
pub const CharacterEditor = struct {};
pub const WorldEditor = struct {};

pub fn init() void {
    ecs.COMPONENT(game.state.world, Mob);
    ecs.COMPONENT(game.state.world, Screen);

    ecs.COMPONENT(game.state.world, Camera);
    ecs.COMPONENT(game.state.world, CameraPosition);
    ecs.COMPONENT(game.state.world, CameraFront);
    ecs.COMPONENT(game.state.world, CameraRotation);
    ecs.COMPONENT(game.state.world, UpDirection);

    ecs.COMPONENT(game.state.world, Perspective);
    // After perspective is applied translation:
    ecs.COMPONENT(game.state.world, PostPerspective);
    // Complete world changes:
    ecs.COMPONENT(game.state.world, WorldTranslation);
    ecs.COMPONENT(game.state.world, WorldRotation);
    ecs.COMPONENT(game.state.world, WorldScale);
    // Where a specific entity is in the world:
    ecs.COMPONENT(game.state.world, WorldLocation);

    ecs.TAG(game.state.world, Data);
    ecs.TAG(game.state.world, Game);
    ecs.TAG(game.state.world, Data);
    ecs.TAG(game.state.world, Cursor);
    ecs.TAG(game.state.world, Settings);
    ecs.TAG(game.state.world, Updated);
    ecs.TAG(game.state.world, NeedsAnimation);
    ecs.TAG(game.state.world, NeedsDemoChunk);

    ecs.TAG(game.state.world, TextureGen);
    ecs.TAG(game.state.world, BlockEditor);
    ecs.TAG(game.state.world, ChunkEditor);
    ecs.TAG(game.state.world, CharacterEditor);
    ecs.TAG(game.state.world, WorldEditor);
}
