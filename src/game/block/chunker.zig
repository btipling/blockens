const minVoxelsInMesh = 1;

chunk: *chunk.Chunk,
numVoxelsInMesh: usize,
currentVoxel: usize,
currentScale: @Vector(4, f32),
toBeMeshed: [minVoxelsInMesh]usize,
cachingMeshed: bool,
meshed: [chunk.chunkSize]bool,
meshes: std.AutoHashMap(usize, @Vector(4, f32)),

const Chunker = @This();

pub fn init(c: *chunk.Chunk) !Chunker {
    // chunkSize
    return Chunker{
        .chunk = c,
        .numVoxelsInMesh = 0,
        .currentVoxel = 0,
        .currentScale = .{ 1, 1, 1, 0 },
        .toBeMeshed = [_]usize{0} ** minVoxelsInMesh,
        .cachingMeshed = true,
        .meshed = [_]bool{false} ** chunk.chunkSize,
        .meshes = std.AutoHashMap(usize, @Vector(4, f32)).init(c.allocator),
    };
}

pub fn deinit(_: *Chunker) void {}

fn updateMeshed(self: *Chunker, i: usize) !void {
    if (self.numVoxelsInMesh < minVoxelsInMesh) {
        self.toBeMeshed[self.numVoxelsInMesh] = i;
        self.numVoxelsInMesh += 1;
        return;
    }
    if (self.cachingMeshed) {
        for (self.toBeMeshed) |ii| {
            self.meshed[ii] = true;
        }
        self.cachingMeshed = false;
        self.toBeMeshed = [_]usize{0} ** minVoxelsInMesh;
    }
    self.meshed[i] = true;
}

fn updateChunk(self: *Chunker) !void {
    try self.meshes.put(self.currentVoxel, self.currentScale);
    self.toBeMeshed = [_]usize{0} ** minVoxelsInMesh;
    self.numVoxelsInMesh = 0;
    self.initScale();
    self.cachingMeshed = true;
}

fn initScale(self: *Chunker) void {
    self.currentScale = .{ 1, 1, 1, 0 };
}

pub fn run(self: *Chunker) !void {
    var op: @Vector(4, f32) = .{ 0, 0, 0, 0 };
    var p = op;
    p[0] += 1;
    var i: usize = 0;
    var firstLoop = true;
    outer: while (true) {
        var numDimsTravelled: u8 = 1;
        while (true) {
            if (firstLoop) {
                // first loop, skip iterating
                firstLoop = false;
                break;
            }
            i += 1;
            if (i >= chunk.chunkSize) {
                break :outer;
            }
            op = chunk.getPositionAtIndexV(i);
            p = op;
            if (p[0] + 1 < chunk.chunkDim) {
                p[0] += 1;
                break;
            }
            if (p[2] + 1 < chunk.chunkDim) {
                numDimsTravelled = 2;
                p[2] += 1;
                break;
            }
            if (p[1] + 1 < chunk.chunkDim) {
                numDimsTravelled = 3;
                p[1] += 1;
                break;
            }
            continue;
        }
        const blockId = self.chunk.data[i];
        if (blockId & 0x00_000_00F == 0) {
            continue :outer;
        }
        if (self.meshed[i]) {
            continue :outer;
        }
        self.currentVoxel = i;
        var endX: f32 = op[0];
        var endZ: f32 = op[2];
        var numXAdded: f32 = 0;
        var numZAdded: f32 = 0;
        inner: while (true) {
            if (numDimsTravelled == 1) {
                const ii = chunk.getIndexFromPositionV(p);
                if (blockId != self.chunk.data[ii] or self.meshed[ii]) {
                    numDimsTravelled += 1;
                    p[0] = op[0];
                    p[2] += 1;
                    p[1] = op[1]; // Happens when near chunk.chunkDims
                    continue :inner;
                }
                if (numXAdded == 0) {
                    numXAdded += 1;
                    try self.updateMeshed(i);
                }
                try self.updateMeshed(ii);
                endX = p[0];
                self.currentScale[0] = endX - op[0] + 1;
                p[0] += 1;
                if (p[0] >= chunk.chunkDim) {
                    numDimsTravelled += 1;
                    p[2] += 1;
                    p[0] = op[0];
                    continue :inner;
                }
                numXAdded += 1;
            } else if (numDimsTravelled == 2) {
                if (p[2] >= chunk.chunkDim) {
                    p[2] = op[2];
                    p[1] += 1;
                    numDimsTravelled += 1;
                    continue :inner;
                }
                const ii = chunk.getIndexFromPositionV(p);
                // doing y here, only add if all x along the y are the same
                if (blockId != self.chunk.data[ii] or self.meshed[ii]) {
                    p[0] = op[0];
                    p[2] = op[2];
                    p[1] += 1;
                    if (p[1] >= chunk.chunkDim) {
                        break :inner;
                    }
                    numDimsTravelled += 1;
                    continue :inner;
                }
                if (numZAdded == 0) {
                    try self.updateMeshed(i);
                }
                if (p[0] != endX) {
                    p[0] += 1;
                    continue :inner;
                }
                // need to add all x's along the y to meshed map
                const _beg = @as(usize, @intFromFloat(op[0]));
                const _end = @as(usize, @intFromFloat(endX)) + 1;
                for (_beg.._end) |xToAdd| {
                    const _xToAdd = @as(f32, @floatFromInt(xToAdd));
                    const np: @Vector(4, f32) = .{ _xToAdd, p[1], p[2], 0 };
                    const iii = chunk.getIndexFromPositionV(np);
                    if (self.chunk.data[iii] != 0) try self.updateMeshed(iii);
                }
                numZAdded += 1;
                endZ = p[2];
                self.currentScale[2] = endZ - op[2] + 1;
                p[2] += 1;
                p[0] = op[0];
            } else {
                const ii = chunk.getIndexFromPositionV(p);
                if (blockId != self.chunk.data[ii]) {
                    break :inner;
                }
                if (self.meshed[ii]) {
                    break :inner;
                }
                if (p[0] != endX) {
                    p[0] += 1;
                    continue :inner;
                }
                if (p[2] != endZ) {
                    p[2] += 1;
                    p[0] = op[0];
                    continue :inner;
                }
                // need to add all x's along the y to meshed map
                const _begX = @as(usize, @intFromFloat(op[0]));
                const _endX = @as(usize, @intFromFloat(endX)) + 1;
                for (_begX.._endX) |xToAdd| {
                    const _xToAdd = @as(f32, @floatFromInt(xToAdd));
                    const _begZ = @as(usize, @intFromFloat(op[2]));
                    const _endZ = @as(usize, @intFromFloat(endZ)) + 1;
                    for (_begZ.._endZ) |zToAdd| {
                        const _zToAdd = @as(f32, @floatFromInt(zToAdd));
                        const iii = chunk.getIndexFromPositionV(.{ _xToAdd, p[1], _zToAdd, 0 });
                        // a one off bug I think?
                        if (self.chunk.data[iii] != 0) try self.updateMeshed(iii);
                    }
                }
                self.currentScale[1] = p[1] - op[1] + 1;
                p[1] += 1;
                p[0] = op[0];
                p[2] = op[2];
                if (p[1] >= chunk.chunkDim) {
                    break :inner;
                }
                continue :inner;
            }
        }
        try self.updateChunk();
    }
    // check final voxel:
    i = chunk.getIndexFromPositionV(.{ 63, 63, 63, 0 });
    const blockId = self.chunk.data[i];
    if (blockId & 0x00_000_00F == 0) {
        return;
    }
    if (self.meshed[i]) {
        return;
    }
    self.meshed[i] = true;
    self.meshes.put(i, .{ 1, 1, 1, 1 }) catch @panic("OOM");
}

const std = @import("std");
const chunk = @import("chunk.zig");
