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
pub const AnimationBlockName: []const u8 = "animation_block";

// Binding points
pub const GameUBOBindingPoint: u32 = 0;
pub const SettingsUBOBindingPoint: u32 = 1;
pub const DemoCubeAnimationBindingPoint: u32 = 2;
pub const CharacterAnimationBindingPoint: u32 = 3;

// Animations
pub const DemoCharacterWalkingAnimationID: u32 = 0x01;
