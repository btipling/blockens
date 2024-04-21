const air: u8 = 0;

traverser: *chunk_traverser,

pub const BlockLighting = @This();

pub fn update_block_lighting(self: *BlockLighting) void {
    self.traverser.reset();
    self.darken_air();
    self.darken_non_light_blocks();
    self.find_full_light_air();
    self.find_bright_air();
    self.find_dark_air();
    self.light_block_surfaces();
}

pub fn darken_air(self: *BlockLighting) void {
    self.traverser.reset();
    // light can emanate up to 5 blocks so go out 6 in each direction in a
    // 6^3 cube to catch edge surfaces.

    // go out by 6
    const y: f32 = self.traverser.position[1] + 6;
    self.traverser.yMoveTo(y);
    const x = self.traverser.position[0] - 6;
    self.traverser.xMoveTo(x);
    const z = self.traverser.position[2] - 6;
    self.traverser.zMoveTo(z);
    // set ends in the x and z direction
    const y_end = y - 12;
    const x_end = x + 12;
    const z_end = z + 12;
    // cull lighting
    while (self.traverser.position[1] >= y_end) : (self.traverser.yNeg()) {
        while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
            while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
                if (self.traverser.current_bd.block_id != air) continue;
                self.traverser.current_bd.lighting = 0;
                self.traverser.saveBD();
            }
            self.traverser.zMoveTo(z);
        }
        self.traverser.xMoveTo(x);
    }
}

pub fn darken_non_light_blocks(self: *BlockLighting) void {
    self.traverser.reset();

    const y: f32 = self.traverser.position[1] + 6;
    self.traverser.yMoveTo(y);
    const x = self.traverser.position[0] - 6;
    self.traverser.xMoveTo(x);
    const z = self.traverser.position[2] - 6;
    self.traverser.zMoveTo(z);
    // set ends in the x and z direction
    const y_end = y - 12;
    const x_end = x + 12;
    const z_end = z + 12;
    // cull lighting
    while (self.traverser.position[1] >= y_end) : (self.traverser.yNeg()) {
        while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
            while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
                if (self.traverser.current_bd.block_id == air) continue;
                if (self.traverser.current_bd.getFullLighting() == .full) continue;
                self.traverser.current_bd.lighting = 0;
                self.traverser.saveBD();
            }
            self.traverser.zMoveTo(z);
        }
        self.traverser.xMoveTo(x);
    }
}

// Find air that can be be fully lit, because it's next to a block light
// This code always finds currently unlit blocks and goes from brightest to darkest
pub fn find_full_light_air(self: *BlockLighting) void {
    self.traverser.reset();

    const y: f32 = self.traverser.position[1] + 6;
    self.traverser.yMoveTo(y);
    const x = self.traverser.position[0] - 6;
    self.traverser.xMoveTo(x);
    const z = self.traverser.position[2] - 6;
    self.traverser.zMoveTo(z);
    // set ends in the x and z direction
    const y_end = y - 12;
    const x_end = x + 12;
    const z_end = z + 12;
    // cull lighting
    while (self.traverser.position[1] >= y_end) : (self.traverser.yNeg()) {
        while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
            while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
                if (self.traverser.current_bd.block_id != air) continue;
                if (self.traverser.current_bd.getFullLighting() != .none) continue;
                if (self.is_adjacent_to_block_light()) {
                    self.traverser.current_bd.setFullLighting(.full);
                    self.traverser.saveBD();
                }
            }
            self.traverser.zMoveTo(z);
        }
        self.traverser.xMoveTo(x);
    }
}

pub fn find_bright_air(self: *BlockLighting) void {
    self.traverser.reset();

    const y: f32 = self.traverser.position[1] + 6;
    self.traverser.yMoveTo(y);
    const x = self.traverser.position[0] - 6;
    self.traverser.xMoveTo(x);
    const z = self.traverser.position[2] - 6;
    self.traverser.zMoveTo(z);
    // set ends in the x and z direction
    const y_end = y - 12;
    const x_end = x + 12;
    const z_end = z + 12;
    // cull lighting
    while (self.traverser.position[1] >= y_end) : (self.traverser.yNeg()) {
        while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
            while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
                if (self.traverser.current_bd.block_id != air) continue;
                if (self.traverser.current_bd.getFullLighting() != .none) continue;
                if (self.is_adjacent_to_lit_air(.full)) {
                    self.traverser.current_bd.setFullLighting(.bright);
                    self.traverser.saveBD();
                }
            }
            self.traverser.zMoveTo(z);
        }
        self.traverser.xMoveTo(x);
    }
}

pub fn find_dark_air(self: *BlockLighting) void {
    self.traverser.reset();

    const y: f32 = self.traverser.position[1] + 6;
    self.traverser.yMoveTo(y);
    const x = self.traverser.position[0] - 6;
    self.traverser.xMoveTo(x);
    const z = self.traverser.position[2] - 6;
    self.traverser.zMoveTo(z);
    // set ends in the x and z direction
    const y_end = y - 12;
    const x_end = x + 12;
    const z_end = z + 12;
    // cull lighting
    while (self.traverser.position[1] >= y_end) : (self.traverser.yNeg()) {
        while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
            while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
                if (self.traverser.current_bd.block_id != air) continue;
                if (self.traverser.current_bd.getFullLighting() != .none) continue;
                if (self.is_adjacent_to_lit_air(.bright)) {
                    self.traverser.current_bd.setFullLighting(.dark);
                    self.traverser.saveBD();
                }
            }
            self.traverser.zMoveTo(z);
        }
        self.traverser.xMoveTo(x);
    }
}

pub fn light_block_surfaces(self: *BlockLighting) void {
    self.traverser.reset();

    const y: f32 = self.traverser.position[1] + 6;
    self.traverser.yMoveTo(y);
    const x = self.traverser.position[0] - 6;
    self.traverser.xMoveTo(x);
    const z = self.traverser.position[2] - 6;
    self.traverser.zMoveTo(z);
    // set ends in the x and z direction
    const y_end = y - 12;
    const x_end = x + 12;
    const z_end = z + 12;
    // cull lighting
    while (self.traverser.position[1] >= y_end) : (self.traverser.yNeg()) {
        while (self.traverser.position[0] < x_end) : (self.traverser.xPos()) {
            while (self.traverser.position[2] < z_end) : (self.traverser.zPos()) {
                if (self.traverser.current_bd.block_id == air) continue;
                if (self.traverser.current_bd.getFullLighting() == .full) continue;
                const cached_pos = self.traverser.position;
                var bd = self.traverser.current_bd;
                {
                    self.traverser.xPos();
                    if (self.traverser.current_bd.block_id == air) {
                        bd.setLighting(.x_pos, self.traverser.current_bd.getFullLighting());
                    }
                }
                self.traverser.xMoveTo(cached_pos[0]);
                {
                    self.traverser.xNeg();
                    if (self.traverser.current_bd.block_id == air) {
                        bd.setLighting(.x_neg, self.traverser.current_bd.getFullLighting());
                    }
                }
                self.traverser.xMoveTo(cached_pos[0]);
                {
                    self.traverser.yPos();
                    if (self.traverser.current_bd.block_id == air) {
                        bd.setLighting(.y_pos, self.traverser.current_bd.getFullLighting());
                    }
                }
                self.traverser.yMoveTo(cached_pos[1]);
                {
                    self.traverser.yNeg();
                    if (self.traverser.current_bd.block_id == air) {
                        bd.setLighting(.y_neg, self.traverser.current_bd.getFullLighting());
                    }
                }
                self.traverser.yMoveTo(cached_pos[1]);
                {
                    self.traverser.zPos();
                    if (self.traverser.current_bd.block_id == air) {
                        bd.setLighting(.z_pos, self.traverser.current_bd.getFullLighting());
                    }
                }
                self.traverser.zMoveTo(cached_pos[2]);
                {
                    self.traverser.zNeg();
                    if (self.traverser.current_bd.block_id == air) {
                        bd.setLighting(.z_neg, self.traverser.current_bd.getFullLighting());
                    }
                }
                self.traverser.zMoveTo(cached_pos[2]);
                self.traverser.current_bd = bd;
                self.traverser.saveBD();
            }
            self.traverser.zMoveTo(z);
        }
        self.traverser.xMoveTo(x);
    }
}

pub fn is_adjacent_to_lit_air(self: BlockLighting, ll: block.BlockLighingLevel) bool {
    const cached_pos = self.traverser.position;
    x_pos: {
        self.traverser.xPos();
        if (self.traverser.current_bd.block_id != air) break :x_pos;
        if (self.traverser.current_bd.getFullLighting() == ll) {
            self.traverser.xMoveTo(cached_pos[0]);
            return true;
        }
    }
    self.traverser.xMoveTo(cached_pos[0]);
    x_neg: {
        self.traverser.xNeg();
        if (self.traverser.current_bd.block_id != air) break :x_neg;
        if (self.traverser.current_bd.getFullLighting() == ll) {
            self.traverser.xMoveTo(cached_pos[0]);
            return true;
        }
    }
    self.traverser.xMoveTo(cached_pos[0]);
    y_pos: {
        self.traverser.yPos();
        if (self.traverser.current_bd.block_id != air) break :y_pos;
        if (self.traverser.current_bd.getFullLighting() == ll) {
            self.traverser.yMoveTo(cached_pos[1]);
            return true;
        }
    }
    self.traverser.yMoveTo(cached_pos[1]);
    y_neg: {
        self.traverser.yNeg();
        if (self.traverser.current_bd.block_id != air) break :y_neg;
        if (self.traverser.current_bd.getFullLighting() == ll) {
            self.traverser.yMoveTo(cached_pos[1]);
            return true;
        }
    }
    self.traverser.yMoveTo(cached_pos[1]);
    z_pos: {
        self.traverser.zPos();
        if (self.traverser.current_bd.block_id != air) break :z_pos;
        if (self.traverser.current_bd.getFullLighting() == ll) {
            self.traverser.zMoveTo(cached_pos[2]);
            return true;
        }
    }
    self.traverser.zMoveTo(cached_pos[2]);
    z_neg: {
        self.traverser.zNeg();
        if (self.traverser.current_bd.block_id != air) break :z_neg;
        if (self.traverser.current_bd.getFullLighting() == ll) {
            self.traverser.zMoveTo(cached_pos[2]);
            return true;
        }
    }
    self.traverser.zMoveTo(cached_pos[2]);
    return false;
}

pub fn is_adjacent_to_block_light(self: BlockLighting) bool {
    const cached_pos = self.traverser.position;
    x_pos: {
        self.traverser.xPos();
        if (self.traverser.current_bd.block_id == air) break :x_pos;
        if (self.traverser.current_bd.getFullLighting() == .full) {
            self.traverser.xMoveTo(cached_pos[0]);
            return true;
        }
    }
    self.traverser.xMoveTo(cached_pos[0]);
    x_neg: {
        self.traverser.xNeg();
        if (self.traverser.current_bd.block_id == air) break :x_neg;
        if (self.traverser.current_bd.getFullLighting() == .full) {
            self.traverser.xMoveTo(cached_pos[0]);
            return true;
        }
    }
    self.traverser.xMoveTo(cached_pos[0]);
    y_pos: {
        self.traverser.yPos();
        if (self.traverser.current_bd.block_id == air) break :y_pos;
        if (self.traverser.current_bd.getFullLighting() == .full) {
            self.traverser.yMoveTo(cached_pos[1]);
            return true;
        }
    }
    self.traverser.yMoveTo(cached_pos[1]);
    y_neg: {
        self.traverser.yNeg();
        if (self.traverser.current_bd.block_id == air) break :y_neg;
        if (self.traverser.current_bd.getFullLighting() == .full) {
            self.traverser.yMoveTo(cached_pos[1]);
            return true;
        }
    }
    self.traverser.yMoveTo(cached_pos[1]);
    z_pos: {
        self.traverser.zPos();
        if (self.traverser.current_bd.block_id == air) break :z_pos;
        if (self.traverser.current_bd.getFullLighting() == .full) {
            self.traverser.zMoveTo(cached_pos[2]);
            return true;
        }
    }
    self.traverser.zMoveTo(cached_pos[2]);
    z_neg: {
        self.traverser.zNeg();
        if (self.traverser.current_bd.block_id == air) break :z_neg;
        if (self.traverser.current_bd.getFullLighting() == .full) {
            self.traverser.zMoveTo(cached_pos[2]);
            return true;
        }
    }
    self.traverser.zMoveTo(cached_pos[2]);
    return false;
}

const std = @import("std");
const block = @import("block.zig");
const chunk = block.chunk;
const chunk_traverser = @import("chunk_traverser.zig");
const data_fetcher = if (@import("builtin").is_test)
    (@import("test_data_fetcher.zig"))
else
    @import("data_fetcher.zig");
const testing_utils = @import("testing_utils.zig");
