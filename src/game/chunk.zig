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
        const blockId = self.data[i];
        std.debug.print("updating mesh for block id: {d}\n", .{blockId});
        try self.meshes.put(i, vp);
    }

    pub fn findMeshes(self: *Chunk) !void {
        const op = position.Position{ .x = 0.0, .y = 0.0, .z = 0.0 };
        var p = op;
        const i = getIndexFromPosition(p);
        const blockId = self.data[i];
        std.debug.print("block id: {d}\n", .{blockId});
        var endX: gl.Float = 0;
        var numDimsTravelled: u8 = 1;
        var numXAdded: gl.Float = 0;
        outer: while (true) {
            p.x += 1.0;
            if (p.x >= chunkDim) {
                endX = op.x + numXAdded;
                if (numDimsTravelled == 1) {
                    numDimsTravelled += 1;
                }
                p.y += 1.0;
                p.x = op.x;
                continue :outer;
            }
            const ii = getIndexFromPosition(p);
            if (numDimsTravelled == 1) {
                if (blockId == self.data[ii]) {
                    try self.meshed.put(i, {});
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
            } else {
                // just doing y here, only add if all x along the y are the same
                if (blockId != self.data[ii]) {
                    std.debug.print("ending: x didn't match on other y\n", .{});
                    break :outer;
                }
                if (p.x != endX) {
                    p.x += 1.0;
                    continue :outer;
                }
                std.debug.print("adding y {d}\n", .{p.y});
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
                for (op.x..@as(usize, @intFromFloat(endX + 1))) |xToAdd| {
                    const _xToAdd = @as(gl.Float, @floatFromInt(xToAdd));
                    const iii = getIndexFromPosition(position.Position{ .x = _xToAdd, .y = p.y, .z = p.z });
                    try self.meshed.put(iii, {});
                }
                p.y += 1.0;
                p.x = op.x;
                if (p.y >= chunkDim) {
                    // p.z += 1.0;
                    // if (p.z >= chunkDim) {
                    //     break: outer;
                    // }
                    // p.y = op.y;
                    // continue :outer;
                    std.debug.print("ending: end of chunk in y\n", .{});
                    break :outer;
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
