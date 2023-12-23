const std = @import("std");
const zm = @import("zmath");
const state = @import("state.zig");
const plane = @import("plane.zig");
const cursor = @import("cursor.zig");

pub const World = struct {
    worldPlane: plane.Plane,
    cursor: cursor.Cursor,
    appState: *state.State,

    pub fn init(worldPlane: plane.Plane, c: cursor.Cursor, appState: *state.State) !World {
        return World{
            .worldPlane = worldPlane,
            .appState = appState,
            .cursor = c,
        };
    }

    pub fn update(self: *World) !void {
        _ = self;
    }

    pub fn draw(self: *World, m: zm.Mat) !void {
        try self.worldPlane.draw(m);
        for (self.appState.game.blocks.items) |b| {
            try b.draw(m);
        }
        try self.cursor.draw(m);
    }
};
