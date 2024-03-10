// shader gen
pub const TransformMatName: []const u8 = "transform";
pub const UBOName: []const u8 = "DataBlock";
pub const UBOMatName: []const u8 = "dataTransform";
pub const UBOGFXDataName: []const u8 = "gfx_data";
pub const UBOAnimationDataName: []const u8 = "animation_data";
pub const AnimationBlockName: []const u8 = "animation_block";

// Binding points
pub const GameUBOBindingPoint: u32 = 0;
pub const SettingsUBOBindingPoint: u32 = 1;
pub const DemoCubeAnimationBindingPoint: u32 = 2;
pub const CharacterAnimationBindingPoint: u32 = 3;

// Animations
pub const DemoCharacterWalkingAnimationID: u32 = 0x01;
