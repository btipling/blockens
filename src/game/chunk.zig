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
        var op = position.Position{ .x = 0.0, .y = 0.0, .z = 0.0 };
        var p = op;
        p.x += 1.0;
        var i: usize = 0;
        var firstLoop = true;
        outer: while (true) {
            while (true) {
                if (firstLoop) {
                    // first loop, skip iterating
                    firstLoop = false;
                    break;
                }
                i += 1;
                if (i >= chunkSize) {
                    break :outer;
                }
                op = getPositionAtIndex(i);
                p = op;
                p.x += 1.0;
                if (p.x >= chunkDim or p.y >= chunkDim or p.z >= chunkDim) {
                    continue;
                }
                break;
            }
            const numMeshes = self.meshes.count();
            if (numMeshes >= 2) {
                break :outer;
            }
            const blockId = self.data[i];
            if (blockId == 0) {
                continue :outer;
            }
            if (self.meshed.contains(i)) {
                continue :outer;
            }
            var numDimsTravelled: u8 = 1;
            var endX: gl.Float = 0;
            var endY: gl.Float = 0;
            var numXAdded: gl.Float = 0;
            var numYAdded: gl.Float = 0;
            inner: while (true) {
                const ii = getIndexFromPosition(p);
                if (numDimsTravelled == 1) {
                    if (blockId != self.data[ii] or self.meshed.contains(ii)) {
                        if (numXAdded > 0) {
                            endX = op.x + numXAdded;
                            numDimsTravelled += 1;
                            p.y += 1.0;
                            p.x = op.x;
                            continue :inner;
                        } else {
                            break :inner;
                        }
                    }
                    if (numXAdded == 0) {
                        try self.meshed.put(i, {});
                    }
                    try self.meshed.put(ii, {});
                    numXAdded += 1;
                    if (self.meshes.get(i)) |vp| {
                        var _vp = vp;
                        _vp.x += 1.0;
                        try self.updateMeshForIndex(i, _vp);
                    } else {
                        var vp = position.Position{ .x = 1.0, .y = 1.0, .z = 1.0 };
                        vp.x += 1.0;
                        try self.updateMeshForIndex(i, vp);
                    }
                    p.x += 1.0;
                    if (p.x >= chunkDim) {
                        endX = op.x + numXAdded;
                        numDimsTravelled += 1;
                        p.y += 1.0;
                        p.x = op.x;
                        continue :inner;
                    }
                } else if (numDimsTravelled == 2) {
                    // doing y here, only add if all x along the y are the same
                    if (blockId != self.data[ii] or self.meshed.contains(ii)) {
                        endY = op.y + numYAdded;
                        p.y = op.y;
                        p.z += 1.0;
                        numDimsTravelled += 1;
                        continue :inner;
                    }
                    if (p.x != endX) {
                        p.x += 1.0;
                        continue :inner;
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
                    const _beg = @as(usize, @intFromFloat(op.x));
                    const _end = @as(usize, @intFromFloat(endX)) + 1;
                    for (_beg.._end) |xToAdd| {
                        const _xToAdd = @as(gl.Float, @floatFromInt(xToAdd));
                        const iii = getIndexFromPosition(position.Position{ .x = _xToAdd, .y = p.y, .z = p.z });
                        try self.meshed.put(iii, {});
                    }
                    numYAdded += 1;
                    p.y += 1.0;
                    p.x = op.x;
                    if (p.y >= chunkDim) {
                        endY = op.y + numYAdded;
                        p.y = op.y;
                        p.z += 1.0;
                        numDimsTravelled += 1;
                        continue :inner;
                    }
                } else {
                    if (blockId != self.data[ii] or self.meshed.contains(ii)) {
                        break :inner;
                    }
                    if (p.x != endX) {
                        p.x += 1.0;
                        continue :inner;
                    }
                    p.y += 1.0;
                    if (p.y != endY) {
                        p.x = op.x;
                        continue :inner;
                    }
                    // need to add all x's along the y to meshed map
                    const _begX = @as(usize, @intFromFloat(op.x));
                    const _endX = @as(usize, @intFromFloat(endX)) + 1;
                    for (_begX.._endX) |xToAdd| {
                        const _xToAdd = @as(gl.Float, @floatFromInt(xToAdd));
                        const _begY = @as(usize, @intFromFloat(op.y));
                        const _endY = @as(usize, @intFromFloat(endY)) + 1;
                        for (_begY.._endY) |yToAdd| {
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
                        break :inner;
                    }
                    continue :inner;
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
