const ecs = @import("zflecs");
const gl = @import("zopengl");
const zm = @import("zmath");
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");

pub const Shape = struct {};

pub const Color = struct {
    r: gl.Float = 0,
    g: gl.Float = 0,
    b: gl.Float = 0,
    a: gl.Float = 0,

    pub fn fromVec(v: math.vecs.Vflx4) Color {
        return Color{
            .r = v.value[0],
            .g = v.value[1],
            .b = v.value[2],
            .a = v.value[3],
        };
    }

    pub fn toVec(self: Color) math.vecs.Vflx4 {
        return math.vecs.Vflx4.initFloats(
            self.r,
            self.g,
            self.b,
            self.a,
        );
    }
};

pub const Rotation = struct {
    w: gl.Float = 0,
    x: gl.Float = 0,
    y: gl.Float = 0,
    z: gl.Float = 0,

    pub fn toVec(self: Rotation) math.vecs.Vflx4 {
        return math.vecs.Vflx4.initFloats(
            self.w,
            self.x,
            self.y,
            self.z,
        );
    }
};

pub const Scale = struct {
    x: gl.Float = 0,
    y: gl.Float = 0,
    z: gl.Float = 0,

    pub fn toVec(self: Scale) math.vecs.Vflx4 {
        return math.vecs.Vflx4.initFloats(
            self.x,
            self.y,
            self.z,
            0,
        );
    }
};

pub const Translation = struct {
    x: gl.Float = 0,
    y: gl.Float = 0,
    z: gl.Float = 0,

    pub fn toVec(self: Translation) math.vecs.Vflx4 {
        return math.vecs.Vflx4.initFloats(
            self.x,
            self.y,
            self.z,
            0,
        );
    }
};

pub const NeedsSetup = struct {};

pub fn init() void {
    ecs.TAG(game.state.world, Shape);
    ecs.COMPONENT(game.state.world, Color);
    ecs.COMPONENT(game.state.world, Rotation);
    ecs.COMPONENT(game.state.world, Scale);
    ecs.COMPONENT(game.state.world, Translation);
    ecs.TAG(game.state.world, NeedsSetup);
}
