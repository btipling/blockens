pub fn migrate(allocator: std.mem.Allocator) !void {
    var data_v1 = try v1.Data.init(allocator);
    defer data_v1.deinit();
    var data_v2 = try v2.Data.init(allocator);
    defer data_v2.deinit();
    // for each chunk row, migrate to gzip
    // drop voxel collumn
    //vacuumn
}

const std = @import("std");
const v1 = @import("data.v1.zig");
const v2 = @import("../../data.zig");
