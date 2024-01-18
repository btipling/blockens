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

    pub fn updateMeshForIndex(self: *Chunk, i: usize, vp: position.Position) !void {
        if (vp.x == 1 and vp.y == 1 and vp.z == 1) {
            return;
        }
        try self.meshes.put(i, vp);
    }

    pub fn findMeshes(self: *Chunk) !void {
        const op = position.Position{ .x = 0.0, .y = 0.0, .z = 0.0 };
        var p = op;
        const i = getIndexFromPosition(p);
        const blockId = self.data[i];
        var numDimsTravelled: u8 = 1;
        var endX: gl.Float = 0;
        var endY: gl.Float = 0;
        var numXAdded: gl.Float = 0;
        var numYAdded: gl.Float = 0;
        p.x += 1.0;
        outer: while (true) {
            const ii = getIndexFromPosition(p);
            if (numDimsTravelled == 1) {
                std.debug.print("d1 - {d} {d} {d}: \n", .{ p.x, p.y, p.z });
                if (blockId == self.data[ii]) {
                    if (numXAdded == 0) {
                        try self.meshed.put(i, {});
                        numXAdded += 1;
                    }
                    try self.meshed.put(ii, {});
                    numXAdded += 1;
                    std.debug.print("numXAdded +1: {d}\n", .{numXAdded});
                    if (self.meshes.get(i)) |vp| {
                        var _vp = vp;
                        _vp.x += 1.0;
                        try self.updateMeshForIndex(i, _vp);
                    } else {
                        var vp = position.Position{ .x = 1.0, .y = 1.0, .z = 1.0 };
                        vp.x += 1.0;
                        try self.updateMeshForIndex(i, vp);
                    }
                } else {
                    if (numXAdded > 0) {
                        endX = op.x + numXAdded;
                        p.x = op.x;
                        numDimsTravelled += 1;
                        p.y += 1.0;
                        continue :outer;
                    } else {
                        std.debug.print("ending: nothing added in x\n", .{});
                        break :outer;
                    }
                }
                p.x += 1.0;
                if (p.x >= chunkDim) {
                    endX = op.x + numXAdded;
                    // std.debug.print("numXAdded: {d}\n", .{numXAdded});
                    numDimsTravelled += 1;
                    p.y += 1.0;
                    p.x = op.x;
                    continue :outer;
                }
            } else if (numDimsTravelled == 2) {
                std.debug.print("d2 - {d} {d} {d}: \n", .{ p.x, p.y, p.z });
                // doing y here, only add if all x along the y are the same
                if (blockId != self.data[ii]) {
                    endY = op.y + numYAdded;
                    p.y = op.y;
                    p.z += 1.0;
                    numDimsTravelled += 1;
                    continue :outer;
                }
                if (p.x != endX) {
                    p.x += 1.0;
                    continue :outer;
                }
                if (self.meshes.get(i)) |vp| {
                    var _vp = vp;
                    _vp.y += 1.0;
                    try self.updateMeshForIndex(i, _vp);
                } else {
                    var vp = position.Position{ .x = 1.0, .y = 1.0, .z = 1.0 };
                    vp.y += 1.0;
                    try self.updateMeshForIndex(i, vp);
                }
                // need to add all x's along the y to meshed map
                for (op.x..@as(usize, @intFromFloat(endX))) |xToAdd| {
                    const _xToAdd = @as(gl.Float, @floatFromInt(xToAdd));
                    const iii = getIndexFromPosition(position.Position{ .x = _xToAdd, .y = p.y, .z = p.z });
                    try self.meshed.put(iii, {});
                }
                numYAdded += 1;
                p.y += 1.0;
                p.x = op.x;
                if (p.y >= chunkDim - 1) {
                    endY = op.y + numYAdded;
                    p.y = op.y;
                    p.z += 1.0;
                    numDimsTravelled += 1;
                    continue :outer;
                }
            } else {
                if (blockId != self.data[ii]) {
                    std.debug.print("ending: x, y didn't match on other y at {d}, {d}, {d}, \n", .{ p.x, p.y, p.z });
                    break :outer;
                }
                if (p.x != endX) {
                    p.x += 1.0;
                    continue :outer;
                }
                p.y += 1.0;
                if (p.y != endY) {
                    std.debug.print("d3 continuing incrementing y - {d} {d} {d}: \n", .{ p.x, p.y, p.z });
                    p.x = op.x;
                    continue :outer;
                }
                // need to add all x's along the y to meshed map
                for (op.x..@as(usize, @intFromFloat(endX + 1))) |xToAdd| {
                    const _xToAdd = @as(gl.Float, @floatFromInt(xToAdd));
                    for (op.x..@as(usize, @intFromFloat(endY + 1))) |yToAdd| {
                        const _yToAdd = @as(gl.Float, @floatFromInt(yToAdd));
                        const iii = getIndexFromPosition(position.Position{ .x = _xToAdd, .y = _yToAdd, .z = p.z });
                        try self.meshed.put(iii, {});
                    }
                }
                if (self.meshes.get(i)) |vp| {
                    var _vp = vp;
                    _vp.z += 1.0;
                    try self.updateMeshForIndex(i, _vp);
                } else {
                    var vp = position.Position{ .x = 1.0, .y = 1.0, .z = 1.0 };
                    vp.z += 1.0;
                    try self.updateMeshForIndex(i, vp);
                }
                p.z += 1.0;
                p.x = op.x;
                p.y = op.y;
                if (p.z >= chunkDim) {
                    std.debug.print("d3 ending z - {d} {d} {d}: \n", .{ p.x, p.y, p.z });
                    break :outer;
                }
                std.debug.print("d3 continuing incrementing z - {d} {d} {d}: \n", .{ p.x, p.y, p.z });
                continue :outer;
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
