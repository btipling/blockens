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
    instanced: std.AutoHashMap(usize, void),
    alloc: std.mem.Allocator,
    pub fn init(alloc: std.mem.Allocator) !Chunk {
        return Chunk{
            .data = [_]i32{0} ** chunkSize,
            .meshes = std.AutoHashMap(usize, position.Position).init(alloc),
            .meshed = std.AutoHashMap(usize, void).init(alloc),
            .instanced = std.AutoHashMap(usize, void).init(alloc),
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Chunk) void {
        self.meshes.deinit();
        self.meshed.deinit();
        self.instanced.deinit();
    }

    pub fn isMeshed(self: *Chunk, i: usize) bool {
        return self.meshed.contains(i);
    }

    pub fn findMeshes(self: *Chunk) !void {
        const start = std.time.milliTimestamp();
        var chunker = try Chunker.init(self);
        try chunker.run();
        const done = std.time.milliTimestamp();
        const duration = (done - start);
        std.debug.print("meshing took {d}ms\n", .{duration});
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
            self.toBeMeshed = [_]usize{0} ** minVoxelsInMesh;
        }
        try self.chunk.meshed.put(i, {});
    }

    fn updateChunk(self: *Chunker, i: usize) !void {
        if (!self.cachingMeshed) {
            try self.chunk.meshes.put(self.currentVoxel, self.currentScale);
        } else {
            try self.chunk.instanced.put(i, {});
            for (self.toBeMeshed) |ii| {
                try self.chunk.instanced.put(ii, {});
            }
        }
        self.toBeMeshed = [_]usize{0} ** minVoxelsInMesh;
        self.numVoxelsInMesh = 0;
        self.initScale();
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
                if (p.x + 1 < chunkDim) {
                    p.x += 1.0;
                    break;
                }
                if (p.y + 1 < chunkDim) {
                    p.y += 1.0;
                    break;
                }
                if (p.z + 1 < chunkDim) {
                    p.z += 1.0;
                    break;
                }
                continue;
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
            var endX: gl.Float = op.x;
            var endY: gl.Float = op.y;
            var numXAdded: gl.Float = 0;
            var numYAdded: gl.Float = 0;
            inner: while (true) {
                const ii = getIndexFromPosition(p);
                if (numDimsTravelled == 1) {
                    if (blockId != self.chunk.data[ii] or self.chunk.meshed.contains(ii)) {
                        numDimsTravelled += 1;
                        p.y += 1.0;
                        p.x = op.x;
                        continue :inner;
                    }
                    if (numXAdded == 0) {
                        numXAdded += 1;
                        try self.updateMeshed(i);
                    }
                    try self.updateMeshed(ii);
                    endX = p.x;

                    self.currentScale.x = endX - op.x + 1;
                    p.x += 1.0;
                    if (p.x >= chunkDim) {
                        std.debug.print("setting endX to: {d} op.x: {d}, numXAdded: {d}\n", .{ endX, op.x, numXAdded });
                        numDimsTravelled += 1;
                        p.y += 1.0;
                        p.x = op.x;
                        continue :inner;
                    }
                    numXAdded += 1;
                } else if (numDimsTravelled == 2) {
                    // doing y here, only add if all x along the y are the same
                    if (blockId != self.chunk.data[ii] or self.chunk.meshed.contains(ii)) {
                        p.y = op.y;
                        p.z += 1.0;
                        numDimsTravelled += 1;
                        continue :inner;
                    }
                    if (numYAdded == 0) {
                        try self.updateMeshed(i);
                    }
                    if (p.x != endX) {
                        p.x += 1.0;
                        continue :inner;
                    }
                    // need to add all x's along the y to meshed map
                    const _beg = @as(usize, @intFromFloat(op.x));
                    const _end = @as(usize, @intFromFloat(endX)) + 1;
                    for (_beg.._end) |xToAdd| {
                        const _xToAdd = @as(gl.Float, @floatFromInt(xToAdd));
                        const np = position.Position{ .x = _xToAdd, .y = p.y, .z = p.z };
                        const iii = getIndexFromPosition(np);
                        try self.updateMeshed(iii);
                    }
                    numYAdded += 1;
                    endY = p.y;
                    self.currentScale.y = endY - op.y + 1;
                    p.y += 1.0;
                    p.x = op.x;
                    if (p.y >= chunkDim) {
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
                    self.currentScale.z = p.z - op.z + 1;
                    p.z += 1.0;
                    p.x = op.x;
                    p.y = op.y;
                    if (p.z >= chunkDim) {
                        break :inner;
                    }
                    continue :inner;
                }
            }
            try self.updateChunk(i);
        }
    }
};
