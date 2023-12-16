const std = @import("std");
const gl = @import("zopengl");
const position = @import("position.zig");
const cube = @import("cube.zig");
const config = @import("config.zig");

pub const maxBlocksDistance = 10;

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

        for (0..config.num_blocks) |_| {
            const b = try getRandomBlock(blocks, alloc);
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

    pub fn getRandomBlock(blocks: std.ArrayList(cube.Cube), alloc: std.mem.Allocator) !cube.Cube {
        var pos: position.Position = undefined;
        var available = false;
        while (!available) {
            pos = randomBlockPosition(blocks.items.len);
            var found = false;
            for (blocks.items) |block| {
                if (block.position.x == pos.x and block.position.y == pos.y and block.position.z == pos.z) {
                    found = true;
                    break;
                }
            }
            available = !found;
        }
        return try cube.Cube.init("block", pos, alloc);
    }

    pub fn randomBlockPosition(
        i: usize,
    ) position.Position {
        var prng = std.rand.DefaultPrng.init(@as(u64, @intCast(i)) + @as(u64, @intCast(std.time.milliTimestamp())));
        const random = prng.random();
        const max = @as(u32, @intFromFloat(maxBlocksDistance));
        const x = @as(gl.Float, @floatFromInt(random.uintAtMost(u32, max)));
        const y = @as(gl.Float, @floatFromInt(random.uintAtMost(u32, max)));
        const z = @as(gl.Float, @floatFromInt(random.uintAtMost(u32, max)));
        std.debug.print("block generated at x: {d}, y: {d}, z: {d} \n", .{ x, y, z });
        return position.Position{ .x = x - max / 2, .y = y, .z = z * -1.0 };
    }
};
