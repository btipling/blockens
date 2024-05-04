pub const Mob = struct {
    mob_id: i32 = 0,
};
pub const Screen = struct {
    current: u64 = 0,
    gameDataEntity: u64 = 0,
    settingDataEntity: u64 = 0,
    ubo: u32 = 0,
    uboBindingPoint: u32 = 0,
};

pub const Camera = struct {
    ubo: u32 = 0,
    elapsedTime: f32 = 0,
};
pub const CurrentCamera = struct {};
pub const CameraPosition = struct {
    pos: @Vector(4, f32) = undefined,
};
pub const CameraFront = struct {
    front: @Vector(4, f32) = undefined,
};

pub const CameraRotation = struct {
    yaw: f32 = 0,
    pitch: f32 = 0,
};

pub const UpDirection = struct {
    up: @Vector(4, f32) = undefined,
};

pub const Perspective = struct {
    fovy: f32,
    aspect: f32,
    near: f32,
    far: f32,
};

pub const WorldTranslation = struct {
    translation: @Vector(4, f32) = undefined,
};

pub const WorldRotation = struct {
    rotation: @Vector(4, f32) = undefined,
};

pub const WorldScale = struct {
    scale: @Vector(4, f32) = undefined,
};

pub const PostPerspective = struct {
    translation: @Vector(4, f32) = undefined,
};

pub const WorldLocation = struct {
    loc: @Vector(4, f32) = undefined,
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
pub const TitleScreen = struct {};
pub const LightingEditor = struct {};
pub const SettingUpScreen = struct {};
pub const LoadingScreen = struct {};
pub const DisplaySettings = struct {};

pub fn init() void {
    const world = game.state.world;
    ecs.COMPONENT(world, Mob);
    ecs.COMPONENT(world, Screen);

    ecs.COMPONENT(world, Camera);
    ecs.TAG(world, CurrentCamera);
    ecs.COMPONENT(world, CameraPosition);
    ecs.COMPONENT(world, CameraFront);
    ecs.COMPONENT(world, CameraRotation);
    ecs.COMPONENT(world, UpDirection);

    ecs.COMPONENT(world, Perspective);
    // After perspective is applied translation:
    ecs.COMPONENT(world, PostPerspective);
    // Complete world changes:
    ecs.COMPONENT(world, WorldTranslation);
    ecs.COMPONENT(world, WorldRotation);
    ecs.COMPONENT(world, WorldScale);
    // Where a specific entity is in the world:
    ecs.COMPONENT(world, WorldLocation);

    ecs.TAG(world, Data);
    ecs.TAG(world, Game);
    ecs.TAG(world, Data);
    ecs.TAG(world, Cursor);
    ecs.TAG(world, Settings);
    ecs.TAG(world, Updated);
    ecs.TAG(world, NeedsAnimation);
    ecs.TAG(world, NeedsDemoChunk);

    ecs.TAG(world, TextureGen);
    ecs.TAG(world, BlockEditor);
    ecs.TAG(world, ChunkEditor);
    ecs.TAG(world, CharacterEditor);
    ecs.TAG(world, WorldEditor);
    ecs.TAG(world, TitleScreen);
    ecs.TAG(world, SettingUpScreen);
    ecs.TAG(world, LoadingScreen);
    ecs.TAG(world, DisplaySettings);
}

const ecs = @import("zflecs");
const game = @import("../../game.zig");
const math = @import("../../math/math.zig");
