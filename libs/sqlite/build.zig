const std = @import("std");
const LazyPath = std.Build.LazyPath;
const Build = std.Build;
const Step = std.Build.Step;

pub const Options = struct {};

pub const path = getPath();

inline fn getPath() []const u8 {
    return std.fs.path.dirname(@src().file) orelse unreachable;
}

pub fn buildLibrary(
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    _: struct { options: Options = .{} },
) *Build.Module {
    _ = optimize;
    _ = target;
    var flags = std.ArrayList([]const u8).init(b.allocator);

    if (b.option(bool, "SQLITE_ENABLE_COLUMN_METADATA", "SQLITE_ENABLE_COLUMN_METADATA") orelse false) {
        flags.append("-DSQLITE_ENABLE_COLUMN_METADATA") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_DBSTAT_VTAB", "SQLITE_ENABLE_DBSTAT_VTAB") orelse false) {
        flags.append("-DSQLITE_ENABLE_DBSTAT_VTAB") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_FTS3", "SQLITE_ENABLE_FTS3") orelse false) {
        flags.append("-DSQLITE_ENABLE_FTS3") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_FTS4", "SQLITE_ENABLE_FTS4") orelse false) {
        flags.append("-DSQLITE_ENABLE_FTS4") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_FTS5", "SQLITE_ENABLE_FTS5") orelse false) {
        flags.append("-DSQLITE_ENABLE_FTS5") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_GEOPOLY", "SQLITE_ENABLE_GEOPOLY") orelse false) {
        flags.append("-DSQLITE_ENABLE_GEOPOLY") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_ICU", "SQLITE_ENABLE_ICU") orelse false) {
        flags.append("-DSQLITE_ENABLE_ICU") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_MATH_FUNCTIONS", "SQLITE_ENABLE_MATH_FUNCTIONS") orelse false) {
        flags.append("-DSQLITE_ENABLE_MATH_FUNCTIONS") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_RBU", "SQLITE_ENABLE_RBU") orelse false) {
        flags.append("-DSQLITE_ENABLE_RBU") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_RTREE", "SQLITE_ENABLE_RTREE") orelse false) {
        flags.append("-DSQLITE_ENABLE_RTREE") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_STAT4", "SQLITE_ENABLE_STAT4") orelse false) {
        flags.append("-DSQLITE_ENABLE_STAT4") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_OMIT_DECLTYPE", "SQLITE_OMIT_DECLTYPE") orelse false) {
        flags.append("-DSQLITE_OMIT_DECLTYPE") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_OMIT_JSON", "SQLITE_OMIT_JSON") orelse false) {
        flags.append("-DSQLITE_OMIT_JSON") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_USE_URI", "SQLITE_USE_URI") orelse false) {
        flags.append("-DSQLITE_USE_URI") catch @panic("OOM");
    }

    const sqlite = b.addModule("sqlite", .{
        .root_source_file = .{ .path = path ++ "/src/sqlite.zig" },
    });
    const sqlite_amalgamation = b.dependency("sqlite_amalgamation", .{});

    sqlite.addIncludePath(sqlite_amalgamation.path("."));
    sqlite.addCSourceFile(.{ .file = sqlite_amalgamation.path("sqlite3.c"), .flags = flags.items });

    return sqlite;
}

pub fn build(b: *std.Build) void {
    var flags = std.ArrayList([]const u8).init(b.allocator);

    if (b.option(bool, "SQLITE_ENABLE_COLUMN_METADATA", "SQLITE_ENABLE_COLUMN_METADATA") orelse false) {
        flags.append("-DSQLITE_ENABLE_COLUMN_METADATA") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_DBSTAT_VTAB", "SQLITE_ENABLE_DBSTAT_VTAB") orelse false) {
        flags.append("-DSQLITE_ENABLE_DBSTAT_VTAB") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_FTS3", "SQLITE_ENABLE_FTS3") orelse false) {
        flags.append("-DSQLITE_ENABLE_FTS3") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_FTS4", "SQLITE_ENABLE_FTS4") orelse false) {
        flags.append("-DSQLITE_ENABLE_FTS4") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_FTS5", "SQLITE_ENABLE_FTS5") orelse false) {
        flags.append("-DSQLITE_ENABLE_FTS5") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_GEOPOLY", "SQLITE_ENABLE_GEOPOLY") orelse false) {
        flags.append("-DSQLITE_ENABLE_GEOPOLY") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_ICU", "SQLITE_ENABLE_ICU") orelse false) {
        flags.append("-DSQLITE_ENABLE_ICU") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_MATH_FUNCTIONS", "SQLITE_ENABLE_MATH_FUNCTIONS") orelse false) {
        flags.append("-DSQLITE_ENABLE_MATH_FUNCTIONS") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_RBU", "SQLITE_ENABLE_RBU") orelse false) {
        flags.append("-DSQLITE_ENABLE_RBU") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_RTREE", "SQLITE_ENABLE_RTREE") orelse false) {
        flags.append("-DSQLITE_ENABLE_RTREE") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_ENABLE_STAT4", "SQLITE_ENABLE_STAT4") orelse false) {
        flags.append("-DSQLITE_ENABLE_STAT4") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_OMIT_DECLTYPE", "SQLITE_OMIT_DECLTYPE") orelse false) {
        flags.append("-DSQLITE_OMIT_DECLTYPE") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_OMIT_JSON", "SQLITE_OMIT_JSON") orelse false) {
        flags.append("-DSQLITE_OMIT_JSON") catch @panic("OOM");
    }

    if (b.option(bool, "SQLITE_USE_URI", "SQLITE_USE_URI") orelse false) {
        flags.append("-DSQLITE_USE_URI") catch @panic("OOM");
    }

    const sqlite = b.addModule("sqlite", .{ .root_source_file = LazyPath.relative("src/sqlite.zig") });
    const sqlite_amalgamation = b.dependency("sqlite_amalgamation", .{});

    sqlite.addIncludePath(sqlite_amalgamation.path("."));
    sqlite.addCSourceFile(.{ .file = sqlite_amalgamation.path("sqlite3.c"), .flags = flags.items });

    // Tests
    const tests = b.addTest(.{ .root_source_file = LazyPath.relative("src/test.zig") });
    tests.addIncludePath(sqlite_amalgamation.path("."));
    tests.addCSourceFile(.{ .file = sqlite_amalgamation.path("sqlite3.c"), .flags = flags.items });

    const run_tests = b.addRunArtifact(tests);

    b.step("test", "Run tests").dependOn(&run_tests.step);
}
