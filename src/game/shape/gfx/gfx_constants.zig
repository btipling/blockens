const gl = @import("zopengl").bindings;

// Binding points
pub const GameUBOBindingPoint: gl.Uint = 0;
pub const SettingsUBOBindingPoint: gl.Uint = 1;
pub const DemoCubeAnimationBindingPoint: gl.Uint = 2;
pub const CharacterAnimationBindingPoint: gl.Uint = 3;

// Animations
pub const DemoCharacterWalkingAnimationID: gl.Uint = 0x01;