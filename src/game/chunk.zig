const std = @import("std");
const zm = @import("zmath");
const ztracy = @import("ztracy");
const config = @import("config");
const blecs = @import("blecs/blecs.zig");
const gfx = @import("gfx/gfx.zig");

pub const chunkDim = 64;
pub const chunkSize: comptime_int = chunkDim * chunkDim * chunkDim;
const drawSize = chunkDim * chunkDim;
const minVoxelsInMesh = 1;

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
    const x = @as(u32, @intFromFloat(p[0]));
    const y = @as(u32, @intFromFloat(p[1]));
    const z = @as(u32, @intFromFloat(p[2]));
    return @as(
        usize,
        @intCast(@mod(x, chunkDim) + @mod(y, chunkDim) * chunkDim + @mod(z, chunkDim) * chunkDim * chunkDim),
    );
}

pub const ChunkElement = struct {
    chunk_index: usize = 0,
    block_id: u8 = 0,
    mesh_data: gfx.mesh.meshData,
    translation: @Vector(4, f32) = .{ 0, 0, 0, 0 },
    fn deinit(self: ChunkElement, allocator: std.mem.Allocator) void {
        allocator.free(self.mesh_data.positions);
        allocator.free(self.mesh_data.normals.?);
        allocator.free(self.mesh_data.indices);
        allocator.free(self.mesh_data.texcoords.?);
    }
};

pub const Chunk = struct {
    wp: worldPosition,
    entity: blecs.ecs.entity_t = 0,
    data: []u32 = undefined,
    meshes: std.AutoHashMap(usize, @Vector(4, f32)),
    allocator: std.mem.Allocator,
    elements: std.ArrayList(ChunkElement) = undefined,
    draws: ?[]c_int = null,
    draw_offsets: ?[]c_int = null, // this only exists to hold the values that draw_offsets_gl points to...
    draw_offsets_gl: ?[]?*const anyopaque = null,
    is_settings: bool = false,
    vbo: u32 = 0,
    pub fn init(
        allocator: std.mem.Allocator,
        wp: worldPosition,
        entity: blecs.ecs.entity_t,
        is_settings: bool,
    ) !*Chunk {
        const c: *Chunk = try allocator.create(Chunk);
        c.* = Chunk{
            .wp = wp,
            .entity = entity,
            .meshes = std.AutoHashMap(usize, @Vector(4, f32)).init(allocator),
            .elements = std.ArrayList(ChunkElement).init(allocator),
            .allocator = allocator,
            .is_settings = is_settings,
        };
        return c;
    }

    pub fn deinit(self: *Chunk) void {
        self.meshes.deinit();
        for (self.elements.items) |ce| {
            ce.deinit(self.allocator);
        }
        self.elements.deinit();
        self.allocator.free(self.data);
        if (self.draws) |d| self.allocator.free(d);
        if (self.draw_offsets) |d| self.allocator.free(d);
        if (self.draw_offsets_gl) |d| self.allocator.free(d);
    }

    pub fn findMeshes(self: *Chunk) !void {
        if (config.use_tracy) {
            const tracy_zone = ztracy.ZoneNC(@src(), "ChunkMeshing", 0x00_00_f0_f0);
            defer tracy_zone.End();
            var chunker = try Chunker.init(self);
            defer chunker.deinit();
            try chunker.run();
        } else {
            var chunker = try Chunker.init(self);
            defer chunker.deinit();
            try chunker.run();
        }
    }
};

pub const Chunker = struct {
    chunk: *Chunk,
    numVoxelsInMesh: usize,
    currentVoxel: usize,
    currentScale: @Vector(4, f32),
    toBeMeshed: [minVoxelsInMesh]usize,
    cachingMeshed: bool,
    meshed: [chunkSize]bool,

    pub fn init(chunk: *Chunk) !Chunker {
        // chunkSize
        return Chunker{
            .chunk = chunk,
            .numVoxelsInMesh = 0,
            .currentVoxel = 0,
            .currentScale = .{ 1, 1, 1, 0 },
            .toBeMeshed = [_]usize{0} ** minVoxelsInMesh,
            .cachingMeshed = true,
            .meshed = [_]bool{false} ** chunkSize,
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
        try self.chunk.meshes.put(self.currentVoxel, self.currentScale);
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
            if (self.meshed[i]) {
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
                    if (blockId != self.chunk.data[ii] or self.meshed[ii]) {
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
                    if (blockId != self.chunk.data[ii] or self.meshed[ii]) {
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
                    if (self.meshed[ii]) {
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
            try self.updateChunk();
        }
    }
};
