const worldPosition = @This();

x: u32,
y: u32,
z: u32,
pub fn initFromPositionV(p: @Vector(4, f32)) worldPosition {
    const x = @as(u32, @bitCast(p[0]));
    const y = @as(u32, @bitCast(p[1]));
    const z = @as(u32, @bitCast(p[2]));
    return worldPosition{
        .x = x,
        .y = y,
        .z = z,
    };
}
pub fn vecFromWorldPosition(self: worldPosition) @Vector(4, f32) {
    const x = @as(f32, @bitCast(self.x));
    const y = @as(f32, @bitCast(self.y));
    const z = @as(f32, @bitCast(self.z));
    return .{ x, y, z, 0 };
}
pub fn equal(self: worldPosition, other: worldPosition) bool {
    return self.x == other.x and self.y == other.y and self.x == other.x;
}

// Get adjacent chunk world positions:
pub fn getFrontWP(self: worldPosition) worldPosition {
    const p = self.vecFromWorldPosition();
    return initFromPositionV(.{ p[0], p[1], p[2] + 1, 0 });
}
pub fn getBackWP(self: worldPosition) worldPosition {
    const p = self.vecFromWorldPosition();
    return initFromPositionV(.{ p[0], p[1], p[2] - 1, 0 });
}
pub fn getLeftWP(self: worldPosition) worldPosition {
    const p = self.vecFromWorldPosition();
    return initFromPositionV(.{ p[0] + 1, p[1], p[2], 0 });
}
pub fn getRightWP(self: worldPosition) worldPosition {
    const p = self.vecFromWorldPosition();
    return initFromPositionV(.{ p[0] - 1, p[1], p[2], 0 });
}
pub fn getBelowWP(self: worldPosition) worldPosition {
    const p = self.vecFromWorldPosition();
    return initFromPositionV(.{ p[0], p[1] - 1, p[2], 0 });
}

pub fn getWorldPositionForWorldLocation(pos: @Vector(4, f32)) worldPosition {
    const chunk_pos = positionFromWorldLocation(pos);
    return worldPosition.initFromPositionV(chunk_pos);
}

pub fn positionFromWorldLocation(loc: @Vector(4, f32)) @Vector(4, f32) {
    const cd: f32 = @floatFromInt(chunk.chunkDim);
    const changer: @Vector(4, f32) = @splat(cd);
    const p = loc / changer;
    return @floor(p);
}

const chunk = @import("chunk.zig");
