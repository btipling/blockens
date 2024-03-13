const std = @import("std");
const zm = @import("zmath");
const blecs = @import("blecs/blecs.zig");

pub const chunkDim = 64;
pub const chunkSize: comptime_int = chunkDim * chunkDim * chunkDim;
const drawSize = chunkDim * chunkDim;
const minVoxelsInMesh = 10;

pub const worldPosition = struct {
    x: u32,
    y: u32,
    z: u32,
    pub fn initFromPositionV(p: @Vector(4, f32)) worldPosition {
        const x = @as(u32, @bitCast(p[0]));
        const y = @as(u32, @bitCast(p[1]));
        const z = @as(u32, @bitCast(p[2]));
        return worldPosition{
            .x = x,
            .y = y,
            .z = z,
        };
    }
    pub fn vecFromWorldPosition(self: worldPosition) @Vector(4, f32) {
        const x = @as(f32, @bitCast(self.x));
        const y = @as(f32, @bitCast(self.y));
        const z = @as(f32, @bitCast(self.z));
        return .{ x, y, z, 0 };
    }
};

pub fn getPositionAtIndexV(i: usize) @Vector(4, f32) {
    const x = @as(f32, @floatFromInt(@mod(i, chunkDim)));
    const y = @as(f32, @floatFromInt(@mod(i / chunkDim, chunkDim)));
    const z = @as(f32, @floatFromInt(i / (chunkDim * chunkDim)));
    return @Vector(4, f32){ x, y, z, 0 };
}

pub fn getIndexFromPositionV(p: @Vector(4, f32)) usize {
    const x = @as(i32, @intFromFloat(p[0]));
    const y = @as(i32, @intFromFloat(p[1]));
    const z = @as(i32, @intFromFloat(p[2]));
    return @as(
        usize,
        @intCast(@mod(x, chunkDim) + @mod(y, chunkDim) * chunkDim + @mod(z, chunkDim) * chunkDim * chunkDim),
    );
}

pub const ChunkElement = struct {
    positions: [][3]f32 = undefined,
    normals: [][3]f32 = null,
    indices: []u32 = undefined,
    transform: zm.Mat = undefined,
    fn deinit(self: ChunkElement, allocator: std.mem.Allocator) void {
        allocator.free(self.positions);
        allocator.free(self.normals);
        allocator.free(self.indices);
    }
};

pub const Chunk = struct {
    wp: worldPosition,
    entity: blecs.ecs.entity_t = 0,
    data: []i32 = undefined,
    meshes: std.AutoHashMap(usize, @Vector(4, f32)),
    meshed: std.AutoHashMap(usize, void),
    instanced: std.AutoHashMap(usize, void),
    allocator: std.mem.Allocator,
    vbo: u32 = 0,
    tm_vbo: u32 = 0,
    elements: std.ArrayList(ChunkElement) = undefined,
    is_settings: bool = false,
    multi_draw: bool = false,
    pub fn init(
        allocator: std.mem.Allocator,
        wp: worldPosition,
        entity: blecs.ecs.entity_t,
        is_settings: bool,
        multi_draw: bool,
    ) !*Chunk {
        const c: *Chunk = try allocator.create(Chunk);
        c.* = Chunk{
            .wp = wp,
            .entity = entity,
            .meshes = std.AutoHashMap(usize, @Vector(4, f32)).init(allocator),
            .meshed = std.AutoHashMap(usize, void).init(allocator),
            .instanced = std.AutoHashMap(usize, void).init(allocator),
            .elements = std.ArrayList(ChunkElement).init(allocator),
            .allocator = allocator,
            .is_settings = is_settings,
            .multi_draw = multi_draw,
        };
        return c;
    }

    pub fn deinit(self: *Chunk) void {
        std.debug.print("deiniting chunk {d}??\n", .{self.entity});
        self.meshes.deinit();
        self.meshed.deinit();
        self.instanced.deinit();
        for (self.elements.items) |ce| {
            ce.deinit(self.allocator);
        }
        self.elements.deinit();
        self.allocator.free(self.data);
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
    currentScale: @Vector(4, f32),
    toBeMeshed: [minVoxelsInMesh]usize,
    cachingMeshed: bool,

    pub fn init(chunk: *Chunk) !Chunker {
        return Chunker{
            .chunk = chunk,
            .numVoxelsInMesh = 0,
            .currentVoxel = 0,
            .currentScale = .{ 1, 1, 1, 0 },
            .toBeMeshed = [_]usize{0} ** minVoxelsInMesh,
            .cachingMeshed = true,
        };
    }

    fn updateMeshed(self: *Chunker, i: usize) !void {
        if (self.chunk.instanced.contains(i)) {
            _ = self.chunk.instanced.remove(i);
        }
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
            if (!self.chunk.meshed.contains(i)) try self.chunk.instanced.put(i, {});
        }
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
                op = getPositionAtIndexV(i);
                p = op;
                if (p[0] + 1 < chunkDim) {
                    p[0] += 1;
                    break;
                }
                if (p[1] + 1 < chunkDim) {
                    p[1] += 1;
                    break;
                }
                if (p[2] + 1 < chunkDim) {
                    p[2] += 1;
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
            var endX: f32 = op[0];
            var endY: f32 = op[1];
            var numXAdded: f32 = 0;
            var numYAdded: f32 = 0;
            inner: while (true) {
                const ii = getIndexFromPositionV(p);
                if (numDimsTravelled == 1) {
                    if (blockId != self.chunk.data[ii] or self.chunk.meshed.contains(ii)) {
                        numDimsTravelled += 1;
                        p[1] += 1;
                        p[0] = op[0];
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
                    if (p[0] >= chunkDim) {
                        numDimsTravelled += 1;
                        p[1] += 1;
                        p[0] = op[0];
                        continue :inner;
                    }
                    numXAdded += 1;
                } else if (numDimsTravelled == 2) {
                    // doing y here, only add if all x along the y are the same
                    if (blockId != self.chunk.data[ii] or self.chunk.meshed.contains(ii)) {
                        p[1] = op[1];
                        p[2] += 1;
                        numDimsTravelled += 1;
                        continue :inner;
                    }
                    if (numYAdded == 0) {
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
                        const iii = getIndexFromPositionV(np);
                        if (self.chunk.data[iii] != 0) try self.updateMeshed(iii);
                    }
                    numYAdded += 1;
                    endY = p[1];
                    self.currentScale[1] = endY - op[1] + 1;
                    p[1] += 1;
                    p[0] = op[0];
                    if (p[1] >= chunkDim) {
                        p[1] = op[1];
                        p[2] += 1;
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
                    if (p[0] != endX) {
                        p[0] += 1;
                        continue :inner;
                    }
                    if (p[1] != endY) {
                        p[1] += 1;
                        p[0] = op[0];
                        continue :inner;
                    }
                    // need to add all x's along the y to meshed map
                    const _begX = @as(usize, @intFromFloat(op[0]));
                    const _endX = @as(usize, @intFromFloat(endX)) + 1;
                    for (_begX.._endX) |xToAdd| {
                        const _xToAdd = @as(f32, @floatFromInt(xToAdd));
                        const _begY = @as(usize, @intFromFloat(op[1]));
                        const _endY = @as(usize, @intFromFloat(endY)) + 1;
                        for (_begY.._endY) |yToAdd| {
                            const _yToAdd = @as(f32, @floatFromInt(yToAdd));
                            const iii = getIndexFromPositionV(.{ _xToAdd, _yToAdd, p[2], 0 });
                            // a one off bug I think?
                            if (self.chunk.data[iii] != 0) try self.updateMeshed(iii);
                        }
                    }
                    self.currentScale[2] = p[2] - op[2] + 1;
                    p[2] += 1;
                    p[0] = op[0];
                    p[1] = op[1];
                    if (p[2] >= chunkDim) {
                        break :inner;
                    }
                    continue :inner;
                }
            }
            try self.updateChunk(i);
        }
    }
};
