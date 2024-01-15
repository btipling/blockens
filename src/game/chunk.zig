const std = @import("std");
const position = @import("position.zig");
const gl = @import("zopengl");

pub const chunkDim = 64;
pub const chunkSize: comptime_int = chunkDim * chunkDim * chunkDim;
const drawSize = chunkDim * chunkDim;

pub const Chunk = struct {
    data: [chunkSize]i32,
    meshes: std.AutoHashMap(usize, std.ArrayList(usize)),
    meshed: std.AutoHashMap(usize, void),
    alloc: std.mem.Allocator,
    pub fn init(alloc: std.mem.Allocator) Chunk {
        return Chunk{
            .data = [_]i32{0} ** chunkSize,
            .meshes = std.AutoHashMap(usize, std.ArrayList(usize)).init(alloc),
            .meshed = std.AutoHashMap(usize, void).init(alloc),
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Chunk) void {
        var mv = self.meshes.valueIterator();
        while (mv.next()) |v| {
            v.deinit();
        }
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
        _ = &p;
        var i = getIndexFromPosition(p);
        _ = &i;
        var blockId = self.data[i];
        _ = &blockId;
        std.debug.print("block id: {d}\n", .{blockId});
        p.x += 1.0;
        const ii = getIndexFromPosition(p);
        if (blockId == self.data[ii]) {
            try self.meshed.put(i, {});
            try self.meshed.put(ii, {});
            if (self.meshes.get(i)) |m| {
                var _m = m;
                try _m.append(ii);
                try self.meshes.put(i, _m);
            } else {
                var m = std.ArrayList(usize).init(self.alloc);
                try m.append(ii);
                try self.meshes.put(i, m);
            }
        } else {
            std.debug.print("different block\n", .{});
        }
    }

    pub fn printMeshes(self: *Chunk) void {
        var keys = self.meshes.keyIterator();
        while (keys.next()) |_k| {
            if (@TypeOf(_k) == *usize) {
                const k = _k.*;
                if (self.meshes.get(k)) |voxels| {
                    std.debug.print("mesh beings at: {d}, members: \n\t", .{k});
                    for (voxels.items) |v| {
                        std.debug.print("{d} ", .{v});
                    }
                    std.debug.print("\n", .{});
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
