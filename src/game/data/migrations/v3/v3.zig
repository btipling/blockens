pub fn migrate(allocator: std.mem.Allocator) !void {
    var db_v3 = try v3.Data.init(allocator);
    defer db_v3.deinit();

    db_v3.db.exec("ALTER TABLE world ADD seed INTEGER DEFAULT 1775 NOT NULL;", .{}) catch |err| {
        std.log.err("Failed to alter world table: {}", .{err});
        return err;
    };
}

const std = @import("std");
const v3 = @import("data.v3.zig");
