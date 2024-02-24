const ecs = @import("zflecs");
const gl = @import("zopengl");
const zm = @import("zmath");
const math = @import("../../math/math.zig");
const game = @import("../../game.zig");

pub const Shape = struct {
    shape_type: ShapeType = .plane,
    pub const ShapeType = enum {
        plane,
        cube,
    };
};

pub const Color = struct {
    color: @Vector(4, gl.Float) = undefined,

    pub fn fromVec(v: math.vecs.Vflx4) Color {
        return Color{
            .color = v.value,
        };
    }

    pub fn toVec(self: Color) math.vecs.Vflx4 {
        return math.vecs.Vflx4.initFloats(
            self.color[0],
            self.color[1],
            self.color[2],
            self.color[3],
        );
    }
};

pub const Rotation = struct {
    rot: @Vector(4, gl.Float) = undefined,

    pub fn toVec(self: Rotation) math.vecs.Vflx4 {
        return math.vecs.Vflx4.initFloats(
            self.rot[0],
            self.rot[1],
            self.rot[2],
            self.rot[3],
        );
    }
};

pub const Scale = struct {
    scale: @Vector(4, gl.Float) = undefined,

    pub fn toVec(self: Scale) math.vecs.Vflx4 {
        return math.vecs.Vflx4.initFloats(
            self.scale[0],
            self.scale[1],
            self.scale[2],
            0,
        );
    }
};

pub const Translation = struct {
    translation: @Vector(4, gl.Float) = undefined,

    pub fn toVec(self: Translation) math.vecs.Vflx4 {
        return math.vecs.Vflx4.initFloats(
            self.translation[0],
            self.translation[1],
            self.translation[2],
            0,
        );
    }
};

pub const DemoCubeTexture = struct {
    beg: usize,
    end: usize,
};

pub const UBO = struct {
    binding_point: gl.Uint = 0,
};

pub const NeedsSetup = struct {};

pub fn init() void {
    ecs.COMPONENT(game.state.world, Shape);
    ecs.COMPONENT(game.state.world, Color);
    ecs.COMPONENT(game.state.world, Rotation);
    ecs.COMPONENT(game.state.world, Scale);
    ecs.COMPONENT(game.state.world, Translation);
    ecs.COMPONENT(game.state.world, UBO);
    ecs.COMPONENT(game.state.world, DemoCubeTexture);
    ecs.TAG(game.state.world, NeedsSetup);
}
