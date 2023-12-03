const std = @import("std");
const gl = @import("zopengl");
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
//
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
        try self.entity.draw();
    }
};
