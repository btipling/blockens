const std = @import("std");
const gl = @import("zopengl");
const position = @import("position.zig");
const cube = @import("cube.zig");
const config = @import("config.zig");

pub const State = struct {
    cameraPos: @Vector(4, gl.Float),
    cameraFront: @Vector(4, gl.Float),
    cameraUp: @Vector(4, gl.Float),
    lastFrame: gl.Float,
    deltaTime: gl.Float,
    firstMouse: bool,
    lastX: gl.Float,
    lastY: gl.Float,
    yaw: gl.Float,
    pitch: gl.Float,
    blocks: std.ArrayList(cube.Cube),

    pub fn init(alloc: std.mem.Allocator) !State {
        var blocks = std.ArrayList(cube.Cube).init(alloc);
        var prng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
        const random = prng.random();

        for (0..config.num_blocks) |_| {
            const b = try getRandomBlock(blocks, alloc, random);
            try blocks.append(b);
        }

        return State{
            .cameraPos = @Vector(4, gl.Float){ 0.0, 1.0, 3.0, 1.0 },
            .cameraFront = @Vector(4, gl.Float){ 0.0, 0.0, -1.0, 0.0 },
            .cameraUp = @Vector(4, gl.Float){ 0.0, 1.0, 0.0, 0.0 },
            .lastFrame = 0.0,
            .deltaTime = 0.0,
            .firstMouse = true,
            .lastX = 0.0,
            .lastY = 0.0,
            .yaw = -90.0,
            .pitch = 0.0,
            .blocks = blocks,
        };
    }

    pub fn deinit(self: *State) void {
        for (self.blocks.items) |block| {
            block.deinit();
        }
    }

    pub fn getRandomBlock(blocks: std.ArrayList(cube.Cube), alloc: std.mem.Allocator, random: std.rand.Random) !cube.Cube {
        var pos: position.Position = undefined;
        var available = false;
        const maxTries = 100;
        var tries: u32 = 0;
        while (!available and tries < maxTries) {
            pos = randomBlockPosition(random);
            var found = false;
            for (blocks.items) |block| {
                if (block.position.x == pos.x and block.position.y == pos.y and block.position.z == pos.z) {
                    found = true;
                    break;
                }
            }
            available = !found;
            tries += 1;
        }
        return try cube.Cube.init("block", randomCubeType(random), pos, alloc);
    }

    pub fn randomCubeType(random: std.rand.Random) cube.CubeType {
        switch (random.uintAtMost(u32, 100)) {
            0...75 => return cube.CubeType.grass,
            76...85 => return cube.CubeType.stone,
            86...97 => return cube.CubeType.sand,
            else => return cube.CubeType.ore,
        }
    }

    pub fn randomXZP(random: std.rand.Random) gl.Float {
        return @as(gl.Float, @floatFromInt(random.uintAtMost(u32, 15)));
    }

    pub fn randomYP(random: std.rand.Random) gl.Float {
        switch (random.uintAtMost(u32, 100)) {
            0...75 => return 0.0,
            76...85 => return 1.0,
            86...95 => return 2.0,
            else => return 3.0,
        }
    }

    pub fn randomBlockPosition(
        random: std.rand.Random,
    ) position.Position {
        return position.Position{ .x = randomXZP(random) - 15 / 2, .y = randomYP(random), .z = (randomXZP(random) * -1.0) };
    }
};
