const std = @import("std");
const position = @import("position.zig");
const gl = @import("zopengl");

pub const chunkDim = 64;
pub const chunkSize: comptime_int = chunkDim * chunkDim * chunkDim;
const drawSize = chunkDim * chunkDim;
const minVoxelsInMesh = 10;

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

pub const Chunk = struct {
    data: [chunkSize]i32,
    meshes: std.AutoHashMap(usize, position.Position),
    meshed: std.AutoHashMap(usize, void),
    alloc: std.mem.Allocator,
    pub fn init(alloc: std.mem.Allocator) !Chunk {
        return Chunk{
            .data = [_]i32{0} ** chunkSize,
            .meshes = std.AutoHashMap(usize, position.Position).init(alloc),
            .meshed = std.AutoHashMap(usize, void).init(alloc),
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Chunk) void {
        self.meshes.deinit();
        self.meshed.deinit();
    }
    pub fn isMeshed(self: *Chunk, i: usize) bool {
        return self.meshed.contains(i);
    }

    pub fn findMeshes(self: *Chunk) !void {
        var chunker = try Chunker.init(self);
        try chunker.run();
    }
};

pub const Chunker = struct {
    chunk: *Chunk,
    numVoxelsInMesh: usize,
    currentVoxel: usize,
    currentScale: position.Position,
    toBeMeshed: [minVoxelsInMesh]usize,
    cachingMeshed: bool,

    pub fn init(chunk: *Chunk) !Chunker {
        return Chunker{
            .chunk = chunk,
            .numVoxelsInMesh = 0,
            .currentVoxel = 0,
            .currentScale = position.Position{ .x = 1.0, .y = 1.0, .z = 1.0 },
            .toBeMeshed = [_]usize{0} ** minVoxelsInMesh,
            .cachingMeshed = true,
        };
    }

    fn updateMeshed(self: *Chunker, i: usize) !void {
        if (self.numVoxelsInMesh < minVoxelsInMesh) {
            self.toBeMeshed[self.numVoxelsInMesh] = i;
            self.numVoxelsInMesh += 1;
            return;
        }
        if (self.cachingMeshed) {
            for (self.toBeMeshed) |ii| {
                try self.chunk.meshed.put(ii, {});
            }
            self.cachingMeshed = false;
        }
        try self.chunk.meshed.put(i, {});
    }

    fn updateChunk(self: *Chunker) !void {
        if (self.numVoxelsInMesh < minVoxelsInMesh) {
            self.numVoxelsInMesh = 0;
            self.initScale();
            return;
        }
        try self.chunk.meshes.put(self.currentVoxel, self.currentScale);
        self.numVoxelsInMesh = 0;
        self.initScale();
        self.toBeMeshed = [_]usize{0} ** minVoxelsInMesh;
        self.cachingMeshed = true;
    }

    fn initScale(self: *Chunker) void {
        self.currentScale = position.Position{ .x = 1.0, .y = 1.0, .z = 1.0 };
    }

    pub fn run(self: *Chunker) !void {
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
            const blockId = self.chunk.data[i];
            if (blockId == 0) {
                continue :outer;
            }
            if (self.chunk.meshed.contains(i)) {
                continue :outer;
            }
            self.currentVoxel = i;
            var numDimsTravelled: u8 = 1;
            var endX: gl.Float = 0;
            var endY: gl.Float = 0;
            var numXAdded: gl.Float = 0;
            var numYAdded: gl.Float = 0;
            inner: while (true) {
                const ii = getIndexFromPosition(p);
                if (numDimsTravelled == 1) {
                    if (blockId != self.chunk.data[ii] or self.chunk.meshed.contains(ii)) {
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
                        try self.updateMeshed(i);
                    }
                    try self.updateMeshed(ii);
                    numXAdded += 1;
                    self.currentScale.x += 1.0;
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
                    if (blockId != self.chunk.data[ii] or self.chunk.meshed.contains(ii)) {
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
                    self.currentScale.y += 1.0;
                    // need to add all x's along the y to meshed map
                    const _beg = @as(usize, @intFromFloat(op.x));
                    const _end = @as(usize, @intFromFloat(endX)) + 1;
                    for (_beg.._end) |xToAdd| {
                        const _xToAdd = @as(gl.Float, @floatFromInt(xToAdd));
                        const iii = getIndexFromPosition(position.Position{ .x = _xToAdd, .y = p.y, .z = p.z });
                        try self.updateMeshed(iii);
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
                    if (blockId != self.chunk.data[ii]) {
                        break :inner;
                    }
                    if (self.chunk.meshed.contains(ii)) {
                        break :inner;
                    }
                    if (p.x != endX) {
                        p.x += 1.0;
                        continue :inner;
                    }
                    if (p.y != endY) {
                        p.y += 1.0;
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
                            try self.updateMeshed(iii);
                        }
                    }
                    self.currentScale.z += 1.0;
                    p.z += 1.0;
                    p.x = op.x;
                    p.y = op.y;
                    if (p.z >= chunkDim) {
                        break :inner;
                    }
                    continue :inner;
                }
            }
            try self.updateChunk();
        }
    }
};
