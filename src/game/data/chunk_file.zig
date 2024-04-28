pub var saves_path: []const u8 = "saves";
pub var chunk_dir_path: []const u8 = "c";

pub fn initSaves(is_absolute: bool) void {
    var dir: std.fs.Dir = undefined;
    if (is_absolute) {
        std.fs.makeDirAbsolute(saves_path) catch |e| {
            std.log.err("unable to create absolute save path {s}. {}\n", .{ saves_path, e });
            return;
        };
        dir = std.fs.openDirAbsolute(saves_path, .{}) catch |e| {
            std.log.err("unable to open absolute save path {s}. {}\n", .{ saves_path, e });
            return;
        };
        return;
    } else {
        std.fs.cwd().makeDir(saves_path) catch |e| {
            std.log.err("unable to create save path {s}. {}\n", .{ saves_path, e });
            return;
        };
        dir = std.fs.cwd().openDir(saves_path, .{}) catch |e| {
            std.log.err("unable to open  save path {s}. {}\n", .{ saves_path, e });
            return;
        };
    }
    dir.makeDir(chunk_dir_path) catch |e| {
        std.log.err("unable to open create chunk saves path {s}/{s}. {}\n", .{
            saves_path,
            chunk_dir_path,
            e,
        });
    };
}

pub fn filePath(world_id: i32, x: i32, z: i32) ![500:0]u8 {
    var buffer: [500:0]u8 = std.mem.zeroes(u8);
    _ = try std.fmt.bufPrint(
        &buffer,
        "{s}/{s}/cd_{s}{d}_{s}{d}.gz",
        .{
            saves_path,
            chunk_dir_path,
            world_id,
            if (x < 0) "n" else "p",
            @abs(x),
            if (z < 0) "n" else "p",
            z,
        },
    );
    return buffer;
}

pub fn saveChunkData(
    allocator: std.mem.Allocator,
    world_id: i32,
    x: i32,
    z: i32,
    top_chunk: []u64,
    bottom_chunk: []u64,
) void {
    const file_path = filePath(world_id, x, z) catch |e| {
        std.log.err("unable to create file name to save chunk. {}\n", .{e});
    };
    const fpath = std.mem.sliceTo(file_path[0..], 0);
    const flags: std.fs.File.CreateFlags = .{
        .lock = .exclusive,
        .lock_nonblocking = true,
    };
    var fh = std.fs.cwd().createFile(fpath, flags) catch |e| {
        std.log.err("unable to save chunk. {}\n", .{e});
        return;
    };
    defer fh.close();
    var c: *compress.Compress = compress.init(allocator, top_chunk, bottom_chunk);
    defer c.deinit();
    c.compress(fh.writer()) catch |e| {
        std.log.err("unable to compress chunk. {}\n", .{e});
        return;
    };
}

const std = @import("std");
const block = @import("../block/block.zig");
const compress = block.compress;
