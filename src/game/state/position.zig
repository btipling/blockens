const std = @import("std");
const gl = @import("zopengl");

pub const Position = struct {
    x: gl.Float,
    y: gl.Float,
    z: gl.Float,
};

pub const Rotation = struct {
    x: gl.Float,
    y: gl.Float,
    z: gl.Float,
};

pub const worldPosition = struct {
    x: u32,
    y: u32,
    z: u32,
    pub fn initFromPosition(p: Position) worldPosition {
        const x = @as(u32, @bitCast(p.x));
        const y = @as(u32, @bitCast(p.y));
        const z = @as(u32, @bitCast(p.z));
        return worldPosition{
            .x = x,
            .y = y,
            .z = z,
        };
    }
    pub fn positionFromWorldPosition(self: worldPosition) Position {
        const x = @as(f32, @bitCast(self.x));
        const y = @as(f32, @bitCast(self.y));
        const z = @as(f32, @bitCast(self.z));
        return Position{
            .x = x,
            .y = y,
            .z = z,
        };
    }
};
