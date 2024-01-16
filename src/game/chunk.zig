const std = @import("std");
const position = @import("position.zig");
const gl = @import("zopengl");

pub const chunkDim = 64;
pub const chunkSize: comptime_int = chunkDim * chunkDim * chunkDim;
const drawSize = chunkDim * chunkDim;

pub const Chunk = struct {
    data: [chunkSize]i32,
    meshes: std.AutoHashMap(usize, position.Position),
    meshed: std.AutoHashMap(usize, void),
    pub fn init(alloc: std.mem.Allocator) Chunk {
        return Chunk{
            .data = [_]i32{0} ** chunkSize,
            .meshes = std.AutoHashMap(usize, position.Position).init(alloc),
            .meshed = std.AutoHashMap(usize, void).init(alloc),
        };
    }

    pub fn deinit(self: *Chunk) void {
        self.meshes.deinit();
        self.meshed.deinit();
    }

    pub fn getPositionAtIndex(i: usize) position.Position {
        const x = @as(gl.Float, @floatFromInt(@mod(i, chunkDim)));
        const y = @as(gl.Float, @floatFromInt(@mod(i / chunkDim, chunkDim)));
        const z = @as(gl.Float, @floatFromInt(i / (chunkDim * chunkDim)));
        return position.Position{ .x = x, .y = y, .z = z };
    }

    pub fn getIndexFromPosition(p: position.Position) usize {
        const x = @as(i32, @intFromFloat(p.x));
        const y = @as(i32, @intFromFloat(p.y));
        const z = @as(i32, @intFromFloat(p.z));
        return @as(
            usize,
            @intCast(@mod(x, chunkDim) + @mod(y, chunkDim) * chunkDim + @mod(z, chunkDim) * chunkDim * chunkDim),
        );
    }

    pub fn findMeshes(self: *Chunk) !void {
        var p = position.Position{ .x = 0.0, .y = 0.0, .z = 0.0 };
        const i = getIndexFromPosition(p);
        const blockId = self.data[i];
        std.debug.print("block id: {d}\n", .{blockId});
        while (true) {
            p.x += 1.0;
            if (p.x >= chunkDim) {
                break;
            }
            std.debug.print("p.x: {d}\n", .{p.x});
            const ii = getIndexFromPosition(p);
            if (blockId == self.data[ii]) {
                try self.meshed.put(i, {});
                try self.meshed.put(ii, {});
                if (self.meshes.get(i)) |vp| {
                    var _vp = vp;
                    _vp.x += 1.0;
                    try self.meshes.put(i, _vp);
                } else {
                    var vp = position.Position{ .x = 1.0, .y = 1.0, .z = 1.0 };
                    vp.x += 1.0;
                    try self.meshes.put(i, vp);
                }
            } else {
                break;
            }
        }
    }

    pub fn printMeshes(self: *Chunk) void {
        var keys = self.meshes.keyIterator();
        while (keys.next()) |_k| {
            if (@TypeOf(_k) == *usize) {
                const k = _k.*;
                if (self.meshes.get(k)) |vp| {
                    std.debug.print("mesh beings at: {d}, members: \n\t", .{k});
                    std.debug.print("voxel needs to grow: x:{d} y:{d} y:{d} ", .{ vp.x, vp.y, vp.z });
                }
            }
        }
    }

    pub fn isMeshed(self: *Chunk, i: usize) bool {
        if (self.meshed.get(i)) |_| {
            return true;
        }
        return false;
    }
};
