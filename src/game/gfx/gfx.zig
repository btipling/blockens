const std = @import("std");
const zm = @import("zmath");
const blecs = @import("../blecs/blecs.zig");
const data = @import("../data/data.zig");
const mob = @import("../mob.zig");
const chunk = @import("../chunk.zig");

pub const shadergen = @import("shadergen.zig");
pub const buffer_data = @import("buffer_data.zig");
pub const constants = @import("gfx_constants.zig");
pub const mesh = @import("mesh.zig");
pub const cltf = @import("cltf_mesh.zig");
pub const gl = @import("gl.zig");

var gfx: *Gfx = undefined;

pub fn init(allocator: std.mem.Allocator) *Gfx {
    mesh.init();
    gfx = allocator.create(Gfx) catch @panic("OOM");
    gfx.* = .{
        .ubos = std.AutoHashMap(u32, u32).init(allocator),
        .ssbos = std.AutoHashMap(u32, u32).init(allocator),
        .renderConfigs = std.AutoHashMap(blecs.ecs.entity_t, *ElementsRendererConfig).init(allocator),
        .game_blocks = std.AutoHashMap(u8, *BlockInstance).init(allocator),
        .settings_blocks = std.AutoHashMap(u8, *BlockInstance).init(allocator),
        .settings_chunks = std.AutoHashMap(chunk.worldPosition, *chunk.Chunk).init(allocator),
        .game_chunks = std.AutoHashMap(chunk.worldPosition, *chunk.Chunk).init(allocator),
        .mob_data = std.AutoHashMap(i32, *mob.Mob).init(allocator),
        .blocks = std.AutoHashMap(u8, *Block).init(allocator),
    };
    return gfx;
}

pub fn deinit(allocator: std.mem.Allocator) void {
    gfx.deinit(allocator);
    allocator.destroy(gfx);
    mesh.deinit();
}

pub const ElementsRendererConfig = struct {
    pub const AnimationKeyFrame = struct {
        frame: f32,
        scale: @Vector(4, f32),
        rotation: @Vector(4, f32),
        translation: @Vector(4, f32),
    };
    pub const MobRef = struct {
        mob_id: i32,
        mesh_id: u32,
    };
    vertexShader: ?[:0]const u8 = null,
    fragmentShader: ?[:0]const u8 = null,
    mesh_data: mesh.meshData = undefined,
    transform: ?zm.Mat = null,
    ubo_binding_point: ?u32 = null,
    demo_cube_texture: ?struct { usize, usize } = null,
    animation_binding_point: ?u32 = null,
    keyframes: ?[]AnimationKeyFrame = null,
    is_instanced: bool = false,
    block_id: ?u8 = 0,
    has_mob_texture: bool = false,
    has_block_texture_atlas: bool = false,
    is_multi_draw: bool = false,
    has_attr_translation: bool = false,
    mob: ?MobRef = null,
};

pub const Block = struct {
    id: u8,
    data: data.block,
};

pub const BlockInstance = struct {
    entity_id: blecs.ecs.entity_t = 0,
    vbo: u32 = 0,
    transforms: std.ArrayList(zm.Mat) = undefined,
};

pub const Gfx = struct {
    ubos: std.AutoHashMap(u32, u32) = undefined,
    ssbos: std.AutoHashMap(u32, u32) = undefined,
    renderConfigs: std.AutoHashMap(blecs.ecs.entity_t, *ElementsRendererConfig) = undefined,
    blocks: std.AutoHashMap(u8, *Block) = undefined,
    game_blocks: std.AutoHashMap(u8, *BlockInstance) = undefined,
    settings_blocks: std.AutoHashMap(u8, *BlockInstance) = undefined,
    mob_data: std.AutoHashMap(i32, *mob.Mob) = undefined,
    animations_running: u32 = 0,
    settings_chunks: std.AutoHashMap(chunk.worldPosition, *chunk.Chunk) = undefined,
    game_chunks: std.AutoHashMap(chunk.worldPosition, *chunk.Chunk) = undefined,

    fn deinit(self: *Gfx, allocator: std.mem.Allocator) void {
        self.ubos.deinit();
        self.ssbos.deinit();
        var cfgs = self.renderConfigs.valueIterator();
        while (cfgs.next()) |rcfg| {
            allocator.destroy(rcfg);
        }
        self.renderConfigs.deinit();
        var blocks = self.blocks.valueIterator();
        while (blocks.next()) |b| {
            allocator.free(b.*.data.texture);
            allocator.destroy(b.*);
        }
        self.blocks.deinit();
        var blocks_i = self.game_blocks.valueIterator();
        while (blocks_i.next()) |b| {
            b.*.transforms.deinit();
            allocator.destroy(b.*);
        }
        self.game_blocks.deinit();
        blocks_i = self.settings_blocks.valueIterator();
        while (blocks_i.next()) |b| {
            b.*.transforms.deinit();
            allocator.destroy(b.*);
        }
        self.settings_blocks.deinit();
        var mb_i = self.mob_data.valueIterator();
        while (mb_i.next()) |m| {
            m.*.deinit();
            allocator.destroy(m.*);
        }
        self.mob_data.deinit();
        var sc_i = self.settings_chunks.valueIterator();
        while (sc_i.next()) |ce| {
            ce.*.deinit();
            allocator.destroy(ce.*);
        }
        self.settings_chunks.deinit();
        var gc_i = self.game_chunks.valueIterator();
        while (gc_i.next()) |ce| {
            ce.*.deinit();
            allocator.destroy(ce.*);
        }
        self.game_chunks.deinit();
    }
};
