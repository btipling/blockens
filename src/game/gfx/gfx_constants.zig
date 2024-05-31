// shader gen
pub const TransformMatName: []const u8 = "transform";
pub const UBOName: []const u8 = "DataBlock";
pub const UBOMatName: []const u8 = "dataTransform";
// gfx_data:
// - index 0 - bitmap of animations running
pub const UBOGFXDataName: []const u8 = "gfx_data";
// block_data:
// - index 0 - a current time frame
// - index 1 - the current texture s value for a cube surface height 0.333/num_blocks
pub const UBOShaderDataName: []const u8 = "shader_data";
pub const AnimationBlockName: []const u8 = "bl_animation_block";
pub const LightingBlockName: []const u8 = "bl_lighting_block";
pub const SubChunksBlockName: []const u8 = "bl_sub_chunks_block";

// UBO binding points
pub const GameUBOBindingPoint: u32 = 0;
pub const SettingsUBOBindingPoint: u32 = 1;

// SSBO binding points
pub const AnimationBindingPoint: u32 = 10;
pub const LightingBindingPoint: u32 = 20;
pub const GameMeshDataBindingPoint: u32 = 30;
pub const SettingsMeshDataBindingPoint: u32 = 40;
pub const GameDrawBindingPoint: u32 = 50;
pub const GameSettingsBindingPoint: u32 = 50;

// Animations
pub const DemoCharacterWalkingAnimationID: u32 = 0x01;
pub const DemoCubeAnimationID: u32 = 0x02;
