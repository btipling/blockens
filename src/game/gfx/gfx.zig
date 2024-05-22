var gfx: *Gfx = undefined;

pub fn init(allocator: std.mem.Allocator) *Gfx {
    mesh.init();
    gfx = allocator.create(Gfx) catch @panic("OOM");
    gfx.* = .{
        .ubos = std.AutoHashMap(u32, u32).init(allocator),
        .ssbos = std.AutoHashMap(u32, u32).init(allocator),
        .renderConfigs = std.AutoHashMap(blecs.ecs.entity_t, *ElementsRendererConfig).init(allocator),
        .mob_data = std.AutoHashMap(i32, *mob.Mob).init(allocator),
        .animation_data = AnimationData.init(allocator),
        .lighting_ssbo = gl.lighting_buffer.initLightingShaderStorageBufferObject(constants.LightingBindingPoint),
    };

    var mb = mesh_buffer_builder{};
    mb.init(mesh.sub_chunk_positions[0..], &gfx.ssbos);

    return gfx;
}

pub fn deinit(allocator: std.mem.Allocator) void {
    gfx.deinit(allocator);
    allocator.destroy(gfx);
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
};

pub const Gfx = struct {
    ubos: std.AutoHashMap(u32, u32) = undefined,
    ssbos: std.AutoHashMap(u32, u32) = undefined,
    renderConfigs: std.AutoHashMap(blecs.ecs.entity_t, *ElementsRendererConfig) = undefined,
    mob_data: std.AutoHashMap(i32, *mob.Mob) = undefined,
    animation_data: AnimationData = undefined,
    lighting_ssbo: u32 = 0,
    ambient_lighting: f32 = 1,

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

    fn deinit(self: *Gfx, allocator: std.mem.Allocator) void {
        self.animation_data.deinit(allocator);
        self.ubos.deinit();
        self.ssbos.deinit();
        var cfgs = self.renderConfigs.valueIterator();
        while (cfgs.next()) |rcfg| {
            allocator.destroy(rcfg);
        }
        self.renderConfigs.deinit();
        var mb_i = self.mob_data.valueIterator();
        while (mb_i.next()) |m| {
            m.*.deinit();
            allocator.destroy(m.*);
        }
        self.mob_data.deinit();
    }

    pub fn addAnimation(self: *Gfx, key: AnimationData.AnimationRefKey, a: *Animation) void {
        self.animation_data.add(key, a, &self.ssbos);
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
