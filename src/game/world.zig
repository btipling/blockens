pub const World = struct {
    pub fn init() !World {
        return World{};
    }

    pub fn update(self: *World) !void {
        _ = self;
    }

    pub fn draw(self: *World) !void {
        _ = self;
    }
};
