var gfx: *Gfx = undefined;

pub fn init(allocator: std.mem.Allocator) *Gfx {
    mesh.init();

    const gbb: mesh_buffer_builder = .{ .mesh_binding_point = constants.GameMeshDataBindingPoint };
    const sbb: mesh_buffer_builder = .{ .mesh_binding_point = constants.SettingsMeshDataBindingPoint };
    gfx = allocator.create(Gfx) catch @panic("OOM");
    gfx.* = .{
        .ubos = std.AutoHashMap(u32, u32).init(allocator),
        .ssbos = std.AutoHashMap(u32, u32).init(allocator),
        .renderConfigs = std.AutoHashMap(blecs.ecs.entity_t, *ElementsRendererConfig).init(allocator),
        .mob_data = std.AutoHashMap(i32, *mob.Mob).init(allocator),
        .animation_data = AnimationData.init(allocator),
        .lighting_ssbo = gl.lighting_buffer.initLightingShaderStorageBufferObject(constants.LightingBindingPoint),
        .game_mesh_buffer_builder = gbb,
        .settings_mesh_buffer_builder = sbb,
        .allocator = allocator,
    };

    gfx.game_mesh_buffer_builder.init(&gfx.ssbos);
    gfx.settings_mesh_buffer_builder.init(&gfx.ssbos);
    gfx.game_sub_chunks_sorter = chunk.sub_chunk.sorter.init(allocator, gfx.game_mesh_buffer_builder);
    gfx.demo_sub_chunks_sorter = chunk.sub_chunk.sorter.init(allocator, gfx.settings_mesh_buffer_builder);

    return gfx;
}

pub fn deinit() void {
    gfx.deinit();
    mesh.deinit();
}

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
    block_id: ?u8 = 0,
    has_mob_texture: bool = false,
    has_block_texture_atlas: bool = false,
    is_multi_draw: bool = false,
    has_attr_translation: bool = false,
    mob: ?MobRef = null,
    is_sub_chunks: bool = false,
};

pub const Gfx = struct {
    ubos: std.AutoHashMap(u32, u32) = undefined,
    ssbos: std.AutoHashMap(u32, u32) = undefined,
    renderConfigs: std.AutoHashMap(blecs.ecs.entity_t, *ElementsRendererConfig) = undefined,
    mob_data: std.AutoHashMap(i32, *mob.Mob) = undefined,
    animation_data: AnimationData = undefined,
    lighting_ssbo: u32 = 0,
    ambient_lighting: f32 = 1,
    demo_sub_chunks_sorter: *chunk.sub_chunk.sorter = undefined,
    game_sub_chunks_sorter: *chunk.sub_chunk.sorter = undefined,
    game_mesh_buffer_builder: mesh_buffer_builder = undefined,
    settings_mesh_buffer_builder: mesh_buffer_builder = undefined,
    allocator: std.mem.Allocator,

    pub fn update_lighting(self: *Gfx) void {
        gl.lighting_buffer.updateLightingShaderStorageBufferObject(
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

    fn deinit(self: *Gfx) void {
        self.animation_data.deinit(self.allocator);
        self.ubos.deinit();
        self.ssbos.deinit();
        self.demo_sub_chunks_sorter.deinit();
        self.game_sub_chunks_sorter.deinit();
        var cfgs = self.renderConfigs.valueIterator();
        while (cfgs.next()) |rcfg| {
            self.allocator.destroy(rcfg);
        }
        self.renderConfigs.deinit();
        var mb_i = self.mob_data.valueIterator();
        while (mb_i.next()) |m| {
            m.*.deinit();
            self.allocator.destroy(m.*);
        }
        self.mob_data.deinit();
        self.allocator.destroy(self);
    }

    pub fn addAnimation(self: *Gfx, key: AnimationData.AnimationRefKey, a: *Animation) void {
        self.animation_data.add(key, a, &self.ssbos);
    }

    pub fn resetDemoSorter(self: *Gfx) void {
        self.demo_sub_chunks_sorter.deinit();
        self.demo_sub_chunks_sorter = chunk.sub_chunk.sorter.init(self.allocator, self.settings_mesh_buffer_builder);
    }
    pub fn resetGameSorter(self: *Gfx) void {
        self.game_sub_chunks_sorter.deinit();
        self.game_sub_chunks_sorter = chunk.sub_chunk.sorter.init(self.allocator, self.game_mesh_buffer_builder);
    }
};

const std = @import("std");
const zm = @import("zmath");
const blecs = @import("../blecs/blecs.zig");
const data = @import("../data/data.zig");
const mob = @import("../mob.zig");
const block = @import("../block/block.zig");
const chunk = block.chunk;

pub const shadergen = @import("shadergen.zig");
pub const buffer_data = @import("buffer_data.zig");
pub const constants = @import("gfx_constants.zig");
pub const mesh = @import("mesh.zig");
pub const cltf = @import("cltf_mesh.zig");
pub const gl = @import("gl.zig");
pub const animation = @import("gfx_animation.zig");
pub const Animation = animation.Animation;
pub const AnimationData = animation.AnimationData;
pub const mesh_buffer_builder = @import("gfx_mesh_buffer_builder.zig");
