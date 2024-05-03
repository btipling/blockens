const std = @import("std");
const sqlite = @import("sqlite");

const listWorldStmt = @embedFile("../../sql/v1/world/list.sql");
const insertChunkDataStmt = @embedFile("../../sql/v1/chunk/insert.sql");
const selectChunkDataByCoordsStmt = @embedFile("../../sql/v1/chunk/select_by_coords.sql");

pub const DataErr = error{
    NotFound,
};

pub const chunkDim = 64;
pub const chunkSize = chunkDim * chunkDim * chunkDim;
// each i32 fits into 4 u8s
pub const ChunkBlobArrayStoreSize = chunkSize * 4;

pub const worldOptionSQL = struct {
    id: i32,
    name: sqlite.Text,
};

pub const worldOption = struct {
    id: i32,
    name: [21]u8,
};

pub const chunkDataSQL = struct {
    id: i32,
    world_id: i32,
    x: i32,
    y: i32,
    z: i32,
    scriptId: i32,
    voxels: sqlite.Blob,
};

pub const chunkData = struct {
    id: i32 = 0,
    world_id: i32 = 0,
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    scriptId: i32 = 0,
    voxels: []u32 = undefined,
};

pub const Data = struct {
    db: sqlite.Database,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Data {
        const db = try sqlite.Database.init(.{ .path = "./gamedata.db" });
        return Data{
            .db = db,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Data) void {
        self.db.deinit();
    }

    fn sqlNameToArray(name: sqlite.Text) [21:0]u8 {
        var n: [21:0]u8 = [_:0]u8{0} ** 21;
        for (name.data, 0..) |c, i| {
            n[i] = c;
            if (c == 0) {
                break;
            }
        }
        return n;
    }

    pub fn listWorlds(self: *Data, data: *std.ArrayList(worldOption)) !void {
        var listStmt = try self.db.prepare(
            struct {},
            worldOptionSQL,
            listWorldStmt,
        );
        defer listStmt.deinit();

        data.clearRetainingCapacity();
        {
            try listStmt.bind(.{});
            defer listStmt.reset();

            while (try listStmt.step()) |row| {
                try data.append(
                    worldOption{
                        .id = row.id,
                        .name = sqlNameToArray(row.name),
                    },
                );
            }
        }
    }

    // chunk crud:
    fn chunkToBlob(chunk: []u32) [ChunkBlobArrayStoreSize]u8 {
        var blob: [ChunkBlobArrayStoreSize]u8 = undefined;
        for (chunk, 0..) |t, i| {
            const u = @as(u32, @bitCast(t));
            const offset = i * 4;
            const a = @as(u8, @truncate(u >> 24));
            const b = @as(u8, @truncate(u >> 16));
            const c = @as(u8, @truncate(u >> 8));
            const d = @as(u8, @truncate(u));
            blob[offset] = a;
            blob[offset + 1] = b;
            blob[offset + 2] = c;
            blob[offset + 3] = d;
        }
        return blob;
    }

    fn blobToChunk(self: *Data, blob: sqlite.Blob) []u32 {
        var chunk: [chunkSize]u32 = undefined;
        for (chunk, 0..) |_, i| {
            const offset = i * 4;
            const a = @as(u32, @intCast(blob.data[offset]));
            const b = @as(u32, @intCast(blob.data[offset + 1]));
            const c = @as(u32, @intCast(blob.data[offset + 2]));
            const d = @as(u32, @intCast(blob.data[offset + 3]));
            const cd: u32 = a << 24 | b << 16 | c << 8 | d;
            chunk[i] = @bitCast(cd);
        }
        const rv: []u32 = self.allocator.alloc(u32, chunk.len) catch unreachable;
        @memcpy(rv, &chunk);
        return rv;
    }

    pub fn saveChunkData(
        self: *Data,
        world_id: i32,
        x: i32,
        y: i32,
        z: i32,
        scriptId: i32,
        voxels: []u32,
    ) !void {
        var insertStmt = try self.db.prepare(
            struct {
                world_id: i32,
                x: i32,
                y: i32,
                z: i32,
                script_id: i32,
                voxels: sqlite.Blob,
            },
            void,
            insertChunkDataStmt,
        );
        defer insertStmt.deinit();

        var t = chunkToBlob(voxels);
        insertStmt.exec(
            .{
                .world_id = world_id,
                .x = x,
                .y = y,
                .z = z,
                .script_id = scriptId,
                .voxels = sqlite.blob(&t),
            },
        ) catch |err| {
            std.log.err("Failed to insert chunkdata: {}", .{err});
            return err;
        };
    }

    pub fn loadChunkData(self: *Data, world_id: i32, x: i32, y: i32, z: i32, data: *chunkData) !void {
        var selectStmt = try self.db.prepare(
            struct {
                x: i32,
                y: i32,
                z: i32,
                world_id: i32,
            },
            struct {
                id: i32,
                world_id: i32,
                x: i32,
                y: i32,
                z: i32,
                script_id: i32,
                voxels: sqlite.Blob,
            },
            selectChunkDataByCoordsStmt,
        );
        defer selectStmt.deinit();

        {
            try selectStmt.bind(.{
                .x = x,
                .y = y,
                .z = z,
                .world_id = world_id,
            });
            defer selectStmt.reset();

            while (try selectStmt.step()) |r| {
                data.id = r.id;
                data.world_id = r.world_id;
                data.x = r.x;
                data.y = r.y;
                data.z = r.z;
                data.scriptId = r.script_id;
                data.voxels = self.blobToChunk(r.voxels);
                return;
            }
        }

        return DataErr.NotFound;
    }
};
