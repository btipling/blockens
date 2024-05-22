pos: chunk.subchunk.subPosition,
data: [chunk.subchunk.subChunkSize]subChunkVoxelData = undefined,

const chunkerSubChunker = @This();

pub fn init(chunk_data: []const u32, pos: chunk.subchunk.subPosition) chunkerSubChunker {
    var csc: chunkerSubChunker = .{
        .pos = pos,
    };
    csc.run(chunk_data);
    return csc;
}

pub const subChunkVoxelData = struct {
    scd: chunk.subchunk.subPositionIndex,
    bd: block.BlockData,
    x_pos: bool = false,
    x_neg: bool = false,
    y_pos: bool = false,
    y_neg: bool = false,
    z_pos: bool = false,
    z_neg: bool = false,
};

fn run(self: *chunkerSubChunker, chunk_data: []const u32) void {
    const pos_x: f32 = self.pos[0] * 16;
    const pos_y: f32 = self.pos[1] * 16;
    const pos_z: f32 = self.pos[2] * 16;

    var i: usize = 0;
    var x: usize = 0;
    while (x < chunk.subchunk.subChunkDim) : (x += 1) {
        const _x: f32 = @floatFromInt(x);
        var z: usize = 0;
        while (z < chunk.subchunk.subChunkDim) : (z += 1) {
            const _z: f32 = @floatFromInt(z);
            var y: usize = 0;
            while (y < chunk.subchunk.subChunkDim) : (y += 1) {
                const _y: f32 = @floatFromInt(y);
                const c_pos: @Vector(4, f32) = .{
                    _x + pos_x,
                    _y + pos_y,
                    _z + pos_z,
                    0,
                };
                const scd = chunk.subchunk.chunkPosToSubPositionData(c_pos);
                self.data[scd.sub_chunk_index] = .{
                    .scd = scd,
                    .bd = block.BlockData.fromId(chunk_data[scd.chunk_index]),
                };
                i += 1;
            }
        }
    }
    i = 0;
    while (i < chunk.subchunk.subChunkSize) : (i += 1) {
        var vd = self.data[i];
        if (vd.bd.block_id == 0) continue;
        x_pos: {
            if (vd.scd.sub_index_pos[0] == chunk.subchunk.subChunkDim - 1) {
                vd.x_pos = true;
                break :x_pos;
            }
        }
        x_neg: {
            if (vd.scd.sub_index_pos[0] == 0) {
                vd.x_neg = true;
                break :x_neg;
            }
        }
        y_pos: {
            if (vd.scd.sub_index_pos[1] == chunk.subchunk.subChunkDim - 1) {
                vd.y_pos = true;
                break :y_pos;
            }
        }
        y_neg: {
            if (vd.scd.sub_index_pos[1] == 0) {
                vd.y_neg = true;
                break :y_neg;
            }
        }
        z_pos: {
            if (vd.scd.sub_index_pos[2] == chunk.subchunk.subChunkDim - 1) {
                vd.z_pos = true;
                break :z_pos;
            }
        }
        z_neg: {
            if (vd.scd.sub_index_pos[2] == 0) {
                vd.z_neg = true;
                break :z_neg;
            }
        }
    }
}

test run {
    const chunk_data = std.testing.allocator.alloc(u32, chunk.chunkSize) catch @panic("OOM");
    defer std.testing.allocator.free(chunk_data);
    @memset(chunk_data, 0);
    var pos: @Vector(4, f32) = .{ 1, 2, 3, 0 };
    const scd = chunk.subchunk.chunkPosToSubPositionData(pos);
    var bd: block.BlockData = block.BlockData.fromId(chunk_data[scd.chunk_index]);
    bd.block_id = 3;
    chunk_data[scd.chunk_index] = bd.toId();
    const t1 = init(chunk_data, scd.sub_pos);
    try std.testing.expectEqual(chunk.subchunk.subChunkSize, t1.data.len);

    var tbd: block.BlockData = t1.data[scd.sub_chunk_index].bd;
    try std.testing.expectEqual(3, tbd.block_id);

    @memset(chunk_data, 0);
    pos = .{ 63, 63, 63, 0 };
    bd = block.BlockData.fromId(0);
    bd.block_id = 3;
    chunk_data[scd.chunk_index] = bd.toId();
    const t2 = init(chunk_data, scd.sub_pos);
    try std.testing.expectEqual(chunk.subchunk.subChunkSize, t2.data.len);
    tbd = t2.data[scd.sub_chunk_index].bd;
    try std.testing.expectEqual(3, tbd.block_id);
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
