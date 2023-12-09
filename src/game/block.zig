const std = @import("std");
const gl = @import("zopengl");
const zm = @import("zmath");
const entity = @import("entity.zig");
const position = @import("position.zig");

const numDataFloats = 32;
const numIndices = 6;

// zig fmt: off
const data: [numDataFloats]gl.Float = .{
    // positions         // colors            // texture coords
     0.5,  0.5, 0.0,     1.0,  0.0,  0.0,     1.0, 1.0, // top right 
     0.5, -0.5, 0.0,     0.0,  1.0,  0.0,     1.0, 0.0, // bottom right
    -0.5, -0.5, 0.0,     0.0,  0.0,  1.0,     0.0, 0.0, // bottom left
    -0.5,  0.5, 0.0,     0.0, 0.25,  0.0,     0.0, 1.0, // top left
};

const indices: [numIndices]gl.Uint = .{
    0, 1, 3,
    1, 2, 3,
};
// zig fmt: on

pub const Block = struct {
    name: []const u8,
    position: position.Position,
    entity: entity.Entity,

    pub fn init(name: []const u8, pos: position.Position) !Block {
        const blockEntity = try entity.Entity.init(
            name,
            &data,
            &indices,
            @embedFile("shaders/block.vs"),
            @embedFile("shaders/block.fs"),
            @embedFile("assets/textures/smilie.png"),
            entity.EntityConfig{ .hasColor = true, .hasTexture = true },
        );
        return Block{
            .name = name,
            .position = pos,
            .entity = blockEntity,
        };
    }

    pub fn deinit(self: *Block) void {
        self.entity.deinit();
    }

    pub fn draw(self: *Block) !void {
        var m = zm.identity();
        m = zm.mul(zm.translation(0.8, 0.0, 0.0), m);
        var angleDegrees: gl.Float = 90.0 * (std.math.pi / 180.0);
        m = zm.mul(zm.rotationZ(angleDegrees), m);
        angleDegrees = 35.0 * (std.math.pi / 180.0);
        m = zm.mul(zm.rotationX(angleDegrees), m);
        angleDegrees = 120.0 * (std.math.pi / 180.0);
        m = zm.mul(zm.rotationY(angleDegrees), m);
        m = zm.mul(zm.scaling(0.5, 0.5, 0.5), m);
        try self.entity.draw(m);
    }
};
