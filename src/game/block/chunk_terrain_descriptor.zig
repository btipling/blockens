pub const noiseConfig = struct {
    frequency: f32,
    jitter: f32,
    octaves: i32,
    noise_type: znoise.FnlGenerator.NoiseType,
};

pub const blockType = enum(u8) {
    air,
    stone,
    grass,
    dirt,
    lava,
    water,
};

pub const blockId = struct {
    block_type: blockType,
    block_id: u8,
};

pub const comparisonOperator = enum(u8) {
    eq,
    gt,
    lt,
    egt,
    elt,
};

pub const yPositionConditional = struct {
    y: usize,
    operator: comparisonOperator,
    is_true: ?descriptorNode,
    is_false: ?descriptorNode,
};

pub const noiseConditional = struct {
    n: f32,
    operator: comparisonOperator,
    is_true: ?descriptorNode,
    is_false: ?descriptorNode,
};

pub const descriptorNode = struct {
    block_type: blockType,
    y_conditional: ?yPositionConditional,
    noise_conditional: ?noiseConditional,
};

pub const root = struct {
    config: noiseConfig,
    block_ids: [256]blockId,
    num_blocks: usize,
    node: descriptorNode,
};

test "basic test" {
    try std.testing.expect(true);
}

const std = @import("std");
const znoise = @import("znoise");
