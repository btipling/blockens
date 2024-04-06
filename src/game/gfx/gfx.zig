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
        .animation_data = AnimationData.init(allocator),
        .lighting_ssbo = gl.Gl.initLightingShaderStorageBufferObject(constants.LightingBindingPoint),
    };

    return gfx;
}

pub fn deinit(allocator: std.mem.Allocator) void {
    gfx.deinit(allocator);
    allocator.destroy(gfx);
    mesh.deinit();
}

pub const Animation = struct {
    pub const AnimationKeyFrame = struct {
        frame: f32,
        scale: @Vector(4, f32),
        rotation: @Vector(4, f32),
        translation: @Vector(4, f32),
    };
    animation_id: u32 = 0,
    animation_offset: usize = 0,
    keyframes: ?[]AnimationKeyFrame = null,
    added: bool = false,
};
pub const AnimationData = struct {
    animation_binding_point: u32 = constants.AnimationBindingPoint,
    data: std.AutoHashMap(AnimationRefKey, *Animation) = undefined,
    animations_running: u32 = constants.DemoCubeAnimationID, // Democube animation is always running atm.
    num_frames: usize = 0,

    // AnimationRefKey - outside of the animation_id, these fields are whatever makes sense, creating
    // and using the same key twice will overwrite previous data which is probably an error.
    pub const AnimationRefKey = struct {
        animation_id: u32,
        animation_mesh_id: u8 = 0,
        ref_id: u8 = 0,
    };

    fn init(allocator: std.mem.Allocator) AnimationData {
        return .{
            .data = std.AutoHashMap(AnimationRefKey, *Animation).init(allocator),
        };
    }

    fn deinit(self: *AnimationData, allocator: std.mem.Allocator) void {
        var it = self.data.iterator();
        while (it.next()) |e| {
            const a: *Animation = e.value_ptr.*;
            if (a.keyframes) |k| allocator.free(k);
            allocator.destroy(a);
        }
        self.data.deinit();
    }

    pub fn add(self: *AnimationData, key: AnimationRefKey, animation: *Animation) void {
        var ssbo: u32 = 0;
        var added = false;
        const kf = animation.keyframes orelse return;

        animation.animation_offset = self.num_frames;
        self.data.put(key, animation) catch @panic("OOM");
        self.num_frames += kf.len;

        ssbo = gfx.ssbos.get(self.animation_binding_point) orelse blk: {
            added = true;
            const new_ssbo = gl.Gl.initAnimationShaderStorageBufferObject(
                self.animation_binding_point,
                kf,
            );
            gfx.ssbos.put(self.animation_binding_point, new_ssbo) catch @panic("OOM");
            break :blk new_ssbo;
        };
        if (!added) {
            gl.Gl.resizeAnimationShaderStorageBufferObject(ssbo, self.num_frames);
            var it = self.data.iterator();
            while (it.next()) |e| {
                const ani: *Animation = e.value_ptr.*;
                const akf = ani.keyframes orelse continue;
                gl.Gl.addAnimationShaderStorageBufferData(ssbo, ani.animation_offset, akf);
            }
        }
    }
};

pub const ElementsRendererConfig = struct {
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
    mob_data: std.AutoHashMap(i32, *mob.Mob) = undefined,
    game_blocks: std.AutoHashMap(u8, *BlockInstance) = undefined,
    settings_blocks: std.AutoHashMap(u8, *BlockInstance) = undefined,
    animation_data: AnimationData = undefined,
    lighting_ssbo: u32 = 0,

    // TODO: I think these belong in some other object, not Gfx:
    game_chunks: std.AutoHashMap(chunk.worldPosition, *chunk.Chunk) = undefined,
    blocks: std.AutoHashMap(u8, *Block) = undefined,
    ambient_lighting: f32 = 1,
    settings_chunks: std.AutoHashMap(chunk.worldPosition, *chunk.Chunk) = undefined,
    selected_block: u8 = 4,

    pub fn update_lighting(self: *Gfx) void {
        gl.Gl.updateLightingShaderStorageBufferObject(
            self.lighting_ssbo,
            0,
            .{
                self.ambient_lighting,
                self.ambient_lighting,
                self.ambient_lighting,
                1,
            },
        );
    }

    fn deinit(self: *Gfx, allocator: std.mem.Allocator) void {
        self.animation_data.deinit(allocator);
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
