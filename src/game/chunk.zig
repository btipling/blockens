pub const chunkDim = 64;
pub const chunkSize: comptime_int = chunkDim * chunkDim * chunkDim;
const drawSize = chunkDim * chunkDim;

pub const Chunk = struct {
    data: [chunkSize]i32,
    pub fn init() Chunk {
        return Chunk{ .data = [_]i32{0} ** chunkSize };
    }
};
