const std = @import("std");
const mem = std.mem;

const bindings = @import("bindings.zig").c;
const versionGreaterThanOrEqualTo = @import("bindings.zig").versionGreaterThanOrEqualTo;

pub const SQLiteExtendedIOError = error{
    SQLiteIOErrRead,
    SQLiteIOErrShortRead,
    SQLiteIOErrWrite,
    SQLiteIOErrFsync,
    SQLiteIOErrDirFsync,
    SQLiteIOErrTruncate,
    SQLiteIOErrFstat,
    SQLiteIOErrUnlock,
    SQLiteIOErrRDLock,
    SQLiteIOErrDelete,
    SQLiteIOErrBlocked,
    SQLiteIOErrNoMem,
    SQLiteIOErrAccess,
    SQLiteIOErrCheckReservedLock,
    SQLiteIOErrLock,
    SQLiteIOErrClose,
    SQLiteIOErrDirClose,
    SQLiteIOErrSHMOpen,
    SQLiteIOErrSHMSize,
    SQLiteIOErrSHMLock,
    SQLiteIOErrSHMMap,
    SQLiteIOErrSeek,
    SQLiteIOErrDeleteNoEnt,
    SQLiteIOErrMmap,
    SQLiteIOErrGetTempPath,
    SQLiteIOErrConvPath,
    SQLiteIOErrVnode,
    SQLiteIOErrAuth,
    SQLiteIOErrBeginAtomic,
    SQLiteIOErrCommitAtomic,
    SQLiteIOErrRollbackAtomic,
    SQLiteIOErrData,
    SQLiteIOErrCorruptFS,
};

pub const SQLiteExtendedCantOpenError = error{
    SQLiteCantOpenNoTempDir,
    SQLiteCantOpenIsDir,
    SQLiteCantOpenFullPath,
    SQLiteCantOpenConvPath,
    SQLiteCantOpenDirtyWAL,
    SQLiteCantOpenSymlink,
};

pub const SQLiteExtendedReadOnlyError = error{
    SQLiteReadOnlyRecovery,
    SQLiteReadOnlyCantLock,
    SQLiteReadOnlyRollback,
    SQLiteReadOnlyDBMoved,
    SQLiteReadOnlyCantInit,
    SQLiteReadOnlyDirectory,
};

pub const SQLiteExtendedConstraintError = error{
    SQLiteConstraintCheck,
    SQLiteConstraintCommitHook,
    SQLiteConstraintForeignKey,
    SQLiteConstraintFunction,
    SQLiteConstraintNotNull,
    SQLiteConstraintPrimaryKey,
    SQLiteConstraintTrigger,
    SQLiteConstraintUnique,
    SQLiteConstraintVTab,
    SQLiteConstraintRowID,
    SQLiteConstraintPinned,
};

pub const SQLiteExtendedError = error{
    SQLiteErrorMissingCollSeq,
    SQLiteErrorRetry,
    SQLiteErrorSnapshot,

    SQLiteLockedSharedCache,
    SQLiteLockedVTab,

    SQLiteBusyRecovery,
    SQLiteBusySnapshot,
    SQLiteBusyTimeout,

    SQLiteCorruptVTab,
    SQLiteCorruptSequence,
    SQLiteCorruptIndex,

    SQLiteAbortRollback,
};

pub const SQLiteError = error{
    SQLiteError,
    SQLiteInternal,
    SQLitePerm,
    SQLiteAbort,
    SQLiteBusy,
    SQLiteLocked,
    SQLiteNoMem,
    SQLiteReadOnly,
    SQLiteInterrupt,
    SQLiteIOErr,
    SQLiteCorrupt,
    SQLiteNotFound,
    SQLiteFull,
    SQLiteCantOpen,
    SQLiteProtocol,
    SQLiteEmpty,
    SQLiteSchema,
    SQLiteTooBig,
    SQLiteConstraint,
    SQLiteMismatch,
    SQLiteMisuse,
    SQLiteNoLFS,
    SQLiteAuth,
    SQLiteRange,
    SQLiteNotADatabase,
    SQLiteNotice,
    SQLiteWarning,
};

pub const Error = SQLiteError ||
    SQLiteExtendedError ||
    SQLiteExtendedIOError ||
    SQLiteExtendedCantOpenError ||
    SQLiteExtendedReadOnlyError ||
    SQLiteExtendedConstraintError;

pub fn errorFromResultCode(code: c_int) Error {
    // These errors are only available since 3.22.0.
    if (comptime versionGreaterThanOrEqualTo(3, 22, 0)) {
        switch (code) {
            bindings.SQLITE_ERROR_MISSING_COLLSEQ => return error.SQLiteErrorMissingCollSeq,
            bindings.SQLITE_ERROR_RETRY => return error.SQLiteErrorRetry,
            bindings.SQLITE_READONLY_CANTINIT => return error.SQLiteReadOnlyCantInit,
            bindings.SQLITE_READONLY_DIRECTORY => return error.SQLiteReadOnlyDirectory,
            else => {},
        }
    }

    // These errors are only available since 3.25.0.
    if (comptime versionGreaterThanOrEqualTo(3, 25, 0)) {
        switch (code) {
            bindings.SQLITE_ERROR_SNAPSHOT => return error.SQLiteErrorSnapshot,
            bindings.SQLITE_LOCKED_VTAB => return error.SQLiteLockedVTab,
            bindings.SQLITE_CANTOPEN_DIRTYWAL => return error.SQLiteCantOpenDirtyWAL,
            bindings.SQLITE_CORRUPT_SEQUENCE => return error.SQLiteCorruptSequence,
            else => {},
        }
    }
    // These errors are only available since 3.31.0.
    if (comptime versionGreaterThanOrEqualTo(3, 31, 0)) {
        switch (code) {
            bindings.SQLITE_CANTOPEN_SYMLINK => return error.SQLiteCantOpenSymlink,
            bindings.SQLITE_CONSTRAINT_PINNED => return error.SQLiteConstraintPinned,
            else => {},
        }
    }
    // These errors are only available since 3.32.0.
    if (comptime versionGreaterThanOrEqualTo(3, 32, 0)) {
        switch (code) {
            bindings.SQLITE_IOERR_DATA => return error.SQLiteIOErrData, // See https://sqlite.org/cksumvfs.html
            bindings.SQLITE_BUSY_TIMEOUT => return error.SQLiteBusyTimeout,
            bindings.SQLITE_CORRUPT_INDEX => return error.SQLiteCorruptIndex,
            else => {},
        }
    }
    // These errors are only available since 3.34.0.
    if (comptime versionGreaterThanOrEqualTo(3, 34, 0)) {
        switch (code) {
            bindings.SQLITE_IOERR_CORRUPTFS => return error.SQLiteIOErrCorruptFS,
            else => {},
        }
    }

    switch (code) {
        bindings.SQLITE_ERROR => return error.SQLiteError,
        bindings.SQLITE_INTERNAL => return error.SQLiteInternal,
        bindings.SQLITE_PERM => return error.SQLitePerm,
        bindings.SQLITE_ABORT => return error.SQLiteAbort,
        bindings.SQLITE_BUSY => return error.SQLiteBusy,
        bindings.SQLITE_LOCKED => return error.SQLiteLocked,
        bindings.SQLITE_NOMEM => return error.SQLiteNoMem,
        bindings.SQLITE_READONLY => return error.SQLiteReadOnly,
        bindings.SQLITE_INTERRUPT => return error.SQLiteInterrupt,
        bindings.SQLITE_IOERR => return error.SQLiteIOErr,
        bindings.SQLITE_CORRUPT => return error.SQLiteCorrupt,
        bindings.SQLITE_NOTFOUND => return error.SQLiteNotFound,
        bindings.SQLITE_FULL => return error.SQLiteFull,
        bindings.SQLITE_CANTOPEN => return error.SQLiteCantOpen,
        bindings.SQLITE_PROTOCOL => return error.SQLiteProtocol,
        bindings.SQLITE_EMPTY => return error.SQLiteEmpty,
        bindings.SQLITE_SCHEMA => return error.SQLiteSchema,
        bindings.SQLITE_TOOBIG => return error.SQLiteTooBig,
        bindings.SQLITE_CONSTRAINT => return error.SQLiteConstraint,
        bindings.SQLITE_MISMATCH => return error.SQLiteMismatch,
        bindings.SQLITE_MISUSE => return error.SQLiteMisuse,
        bindings.SQLITE_NOLFS => return error.SQLiteNoLFS,
        bindings.SQLITE_AUTH => return error.SQLiteAuth,
        bindings.SQLITE_RANGE => return error.SQLiteRange,
        bindings.SQLITE_NOTADB => return error.SQLiteNotADatabase,
        bindings.SQLITE_NOTICE => return error.SQLiteNotice,
        bindings.SQLITE_WARNING => return error.SQLiteWarning,

        bindings.SQLITE_IOERR_READ => return error.SQLiteIOErrRead,
        bindings.SQLITE_IOERR_SHORT_READ => return error.SQLiteIOErrShortRead,
        bindings.SQLITE_IOERR_WRITE => return error.SQLiteIOErrWrite,
        bindings.SQLITE_IOERR_FSYNC => return error.SQLiteIOErrFsync,
        bindings.SQLITE_IOERR_DIR_FSYNC => return error.SQLiteIOErrDirFsync,
        bindings.SQLITE_IOERR_TRUNCATE => return error.SQLiteIOErrTruncate,
        bindings.SQLITE_IOERR_FSTAT => return error.SQLiteIOErrFstat,
        bindings.SQLITE_IOERR_UNLOCK => return error.SQLiteIOErrUnlock,
        bindings.SQLITE_IOERR_RDLOCK => return error.SQLiteIOErrRDLock,
        bindings.SQLITE_IOERR_DELETE => return error.SQLiteIOErrDelete,
        bindings.SQLITE_IOERR_BLOCKED => return error.SQLiteIOErrBlocked,
        bindings.SQLITE_IOERR_NOMEM => return error.SQLiteIOErrNoMem,
        bindings.SQLITE_IOERR_ACCESS => return error.SQLiteIOErrAccess,
        bindings.SQLITE_IOERR_CHECKRESERVEDLOCK => return error.SQLiteIOErrCheckReservedLock,
        bindings.SQLITE_IOERR_LOCK => return error.SQLiteIOErrLock,
        bindings.SQLITE_IOERR_CLOSE => return error.SQLiteIOErrClose,
        bindings.SQLITE_IOERR_DIR_CLOSE => return error.SQLiteIOErrDirClose,
        bindings.SQLITE_IOERR_SHMOPEN => return error.SQLiteIOErrSHMOpen,
        bindings.SQLITE_IOERR_SHMSIZE => return error.SQLiteIOErrSHMSize,
        bindings.SQLITE_IOERR_SHMLOCK => return error.SQLiteIOErrSHMLock,
        bindings.SQLITE_IOERR_SHMMAP => return error.SQLiteIOErrSHMMap,
        bindings.SQLITE_IOERR_SEEK => return error.SQLiteIOErrSeek,
        bindings.SQLITE_IOERR_DELETE_NOENT => return error.SQLiteIOErrDeleteNoEnt,
        bindings.SQLITE_IOERR_MMAP => return error.SQLiteIOErrMmap,
        bindings.SQLITE_IOERR_GETTEMPPATH => return error.SQLiteIOErrGetTempPath,
        bindings.SQLITE_IOERR_CONVPATH => return error.SQLiteIOErrConvPath,
        bindings.SQLITE_IOERR_VNODE => return error.SQLiteIOErrVnode,
        bindings.SQLITE_IOERR_AUTH => return error.SQLiteIOErrAuth,
        bindings.SQLITE_IOERR_BEGIN_ATOMIC => return error.SQLiteIOErrBeginAtomic,
        bindings.SQLITE_IOERR_COMMIT_ATOMIC => return error.SQLiteIOErrCommitAtomic,
        bindings.SQLITE_IOERR_ROLLBACK_ATOMIC => return error.SQLiteIOErrRollbackAtomic,

        bindings.SQLITE_LOCKED_SHAREDCACHE => return error.SQLiteLockedSharedCache,

        bindings.SQLITE_BUSY_RECOVERY => return error.SQLiteBusyRecovery,
        bindings.SQLITE_BUSY_SNAPSHOT => return error.SQLiteBusySnapshot,

        bindings.SQLITE_CANTOPEN_NOTEMPDIR => return error.SQLiteCantOpenNoTempDir,
        bindings.SQLITE_CANTOPEN_ISDIR => return error.SQLiteCantOpenIsDir,
        bindings.SQLITE_CANTOPEN_FULLPATH => return error.SQLiteCantOpenFullPath,
        bindings.SQLITE_CANTOPEN_CONVPATH => return error.SQLiteCantOpenConvPath,

        bindings.SQLITE_CORRUPT_VTAB => return error.SQLiteCorruptVTab,

        bindings.SQLITE_READONLY_RECOVERY => return error.SQLiteReadOnlyRecovery,
        bindings.SQLITE_READONLY_CANTLOCK => return error.SQLiteReadOnlyCantLock,
        bindings.SQLITE_READONLY_ROLLBACK => return error.SQLiteReadOnlyRollback,
        bindings.SQLITE_READONLY_DBMOVED => return error.SQLiteReadOnlyDBMoved,

        bindings.SQLITE_ABORT_ROLLBACK => return error.SQLiteAbortRollback,

        bindings.SQLITE_CONSTRAINT_CHECK => return error.SQLiteConstraintCheck,
        bindings.SQLITE_CONSTRAINT_COMMITHOOK => return error.SQLiteConstraintCommitHook,
        bindings.SQLITE_CONSTRAINT_FOREIGNKEY => return error.SQLiteConstraintForeignKey,
        bindings.SQLITE_CONSTRAINT_FUNCTION => return error.SQLiteConstraintFunction,
        bindings.SQLITE_CONSTRAINT_NOTNULL => return error.SQLiteConstraintNotNull,
        bindings.SQLITE_CONSTRAINT_PRIMARYKEY => return error.SQLiteConstraintPrimaryKey,
        bindings.SQLITE_CONSTRAINT_TRIGGER => return error.SQLiteConstraintTrigger,
        bindings.SQLITE_CONSTRAINT_UNIQUE => return error.SQLiteConstraintUnique,
        bindings.SQLITE_CONSTRAINT_VTAB => return error.SQLiteConstraintVTab,
        bindings.SQLITE_CONSTRAINT_ROWID => return error.SQLiteConstraintRowID,

        else => std.debug.panic("invalid result code {}", .{code}),
    }
}

/// DetailedError contains a SQLite error code and error message.
pub const DetailedError = struct {
    code: usize,
    near: i32,
    message: []const u8,

    pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        _ = try writer.print("{{code: {}, near: {d}, message: {s}}}", .{ self.code, self.near, self.message });
    }
};

pub fn getDetailedErrorFromResultCode(code: c_int) DetailedError {
    return .{
        .code = @intCast(code),
        .near = -1,
        .message = blk: {
            const msg = bindings.sqlite3_errstr(code);
            break :blk mem.sliceTo(msg, 0);
        },
    };
}

pub fn getErrorOffset(db: *bindings.sqlite3) i32 {
    if (comptime versionGreaterThanOrEqualTo(3, 38, 0)) {
        return bindings.sqlite3_error_offset(db);
    }
    return -1;
}

pub fn getLastDetailedErrorFromDb(db: *bindings.sqlite3) DetailedError {
    return .{
        .code = @intCast(bindings.sqlite3_extended_errcode(db)),
        .near = getErrorOffset(db),
        .message = blk: {
            const msg = bindings.sqlite3_errmsg(db);
            break :blk mem.sliceTo(msg, 0);
        },
    };
}
