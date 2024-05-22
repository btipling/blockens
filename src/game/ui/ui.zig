pub const max_world_name = 20;

const robotoMonoFont = @embedFile("../assets/fonts/Roboto_Mono/RobotoMono-Regular.ttf");
const proggyCleanFont = @embedFile("../assets/fonts/ProggyClean/ProggyClean.ttf");

pub const chunkConfig = struct {
    id: i32 = 0, // from sqlite
    scriptId: i32 = 0,
    chunkData: []u32 = undefined,
};

game_font: zgui.Font = undefined,
code_font: zgui.Font = undefined,

allocator: std.mem.Allocator,

texture_script_options: std.ArrayListUnmanaged(data.scriptOption) = undefined,
texture_loaded_script_id: i32 = 0,
texture_buf: [script.maxLuaScriptSize]u8 = std.mem.zeroes([script.maxLuaScriptSize]u8),
texture_name_buf: [script.maxLuaScriptNameSize]u8 = std.mem.zeroes([script.maxLuaScriptNameSize]u8),
texture_rgba_data: ?[]u32 = null,
texture_atlas_rgba_data: ?[]u32 = null,
texture_atlas_block_index: [blecs.entities.block.MaxBlocks]usize = std.mem.zeroes([blecs.entities.block.MaxBlocks]usize),
texture_atlas_num_blocks: usize = 0,

block_options: std.ArrayListUnmanaged(data.blockOption) = undefined,
block_create_name_buf: [data.maxBlockSizeName]u8 = std.mem.zeroes([data.maxBlockSizeName]u8),
block_update_name_buf: [data.maxBlockSizeName]u8 = std.mem.zeroes([data.maxBlockSizeName]u8),
block_emits_light: bool = false,
block_transparent: bool = false,
block_loaded_block_id: u8 = 0,
block_picking_distance: f32 = 20,

display_settings_fullscreen: bool = false,
display_settings_maximized: bool = true,
display_settings_decorated: bool = false,
display_settings_width: i32 = 0,
display_settings_height: i32 = 0,

chunk_name_buf: [script.maxLuaScriptNameSize]u8 = std.mem.zeroes([script.maxLuaScriptNameSize]u8),
chunk_buf: [script.maxLuaScriptSize]u8 = std.mem.zeroes([script.maxLuaScriptSize]u8),
chunks_small: bool = false,
chunk_script_options: std.ArrayListUnmanaged(data.colorScriptOption) = undefined,
chunk_loaded_script_id: i32 = 0,
chunk_script_color: [3]f32 = std.mem.zeroes([3]f32),

terrain_gen_seed: i32 = 1531,
terrain_gen_name_buf: [script.maxLuaScriptNameSize]u8 = std.mem.zeroes([script.maxLuaScriptNameSize]u8),
terrain_gen_buf: [script.maxLuaScriptSize]u8 = std.mem.zeroes([script.maxLuaScriptSize]u8),
terrain_gen_x_buf: i32 = 0,
terrain_gen_z_buf: i32 = 0,
terrain_gen_script_options: std.ArrayListUnmanaged(data.colorScriptOption) = undefined,
terrain_gen_script_options_available: std.ArrayListUnmanaged(data.colorScriptOption) = undefined,
terrain_gen_script_options_selected: std.ArrayListUnmanaged(data.colorScriptOption) = undefined,
terrain_gen_loaded_script_id: i32 = 0,
terrain_gen_script_color: [3]f32 = std.mem.zeroes([3]f32),

world_name_buf: [max_world_name]u8 = std.mem.zeroes([max_world_name]u8),
world_options: std.ArrayListUnmanaged(data.worldOption) = undefined,
world_chunk_table_data: std.AutoHashMapUnmanaged(chunk.worldPosition, chunkConfig) = undefined,
world_loaded_name: [max_world_name:0]u8 = std.mem.zeroes([max_world_name:0]u8),
world_loaded_id: i32 = 0,
world_mananaged_id: i32 = 0,
world_managed_name: [max_world_name:0]u8 = std.mem.zeroes([max_world_name:0]u8),
world_managed_seed: i32 = 0,
world_managed_seed_terrain_scripts: std.ArrayListUnmanaged(data.colorScriptOption) = undefined,
world_player_relocation: @Vector(4, f32) = .{ 32, 64, 32, 0 },

demo_screen_rotation_x: f32 = 0,
demo_screen_rotation_y: f32 = 0.341,
demo_screen_rotation_z: f32 = 0.083,

demo_screen_scale: f32 = 0,
demo_screen_translation: @Vector(4, f32) = .{ 0, 0, 0, 0 },
demo_screen_pp_translation: @Vector(4, f32) = .{ 0, 0, 0, 0 },

demo_cube_rotation: @Vector(4, f32) = zm.matToQuat(zm.rotationY(0 * std.math.pi)),
demo_cube_translation: @Vector(4, f32) = @Vector(4, f32){ 0, 0, 0, 0 },
demo_cube_pp_translation: @Vector(4, f32) = @Vector(4, f32){ -0.825, 0.650, 0, 0 },
demo_cube_plane_1_tl: @Vector(4, f32) = @Vector(4, f32){ -0.926, 0.12, 0, 0 },
demo_cube_plane_1_t2: @Vector(4, f32) = @Vector(4, f32){ -0.727, 0.090, 0, 0 },
demo_cube_plane_1_t3: @Vector(4, f32) = @Vector(4, f32){ -0.926, -0.54, 0, 0 },
demo_atlas_scale: @Vector(4, f32) = @Vector(4, f32){ 0.100, 1.940, 1, 0 },
demo_atlas_translation: @Vector(4, f32) = @Vector(4, f32){ -0.976, -0.959, 0, 0 },
demo_atlas_rotation: f32 = 0.5,

demo_sub_chunks_sorter: *chunk.subchunk.sorter,

load_percentage_world_gen: f16 = 0,
load_percentage_lighting_initial: f16 = 0,
load_percentage_lighting_cross_chunk: f16 = 0,
load_percentage_load_chunks: f16 = 0,

gfx_wire_frames: bool = false,
gfx_lock_cull_to_player_pos: bool = false,
gfx_meshes_drawn_counter: u64 = 0,
gfx_meshes_drawn: u64 = 0,

screen_size: [2]f32 = .{ 0, 0 },

const UI = @This();
pub var ui: *UI = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    ui = allocator.create(UI) catch @panic("OOM");

    ui.* = .{
        .allocator = allocator,
        .texture_script_options = std.ArrayListUnmanaged(data.scriptOption){},
        .block_options = std.ArrayListUnmanaged(data.blockOption){},
        .chunk_script_options = std.ArrayListUnmanaged(data.colorScriptOption){},
        .world_options = std.ArrayListUnmanaged(data.worldOption){},
        .world_chunk_table_data = std.AutoHashMapUnmanaged(chunk.worldPosition, chunkConfig){},
        .terrain_gen_script_options = std.ArrayListUnmanaged(data.colorScriptOption){},
        .terrain_gen_script_options_available = std.ArrayListUnmanaged(data.colorScriptOption){},
        .terrain_gen_script_options_selected = std.ArrayListUnmanaged(data.colorScriptOption){},
        .world_managed_seed_terrain_scripts = std.ArrayListUnmanaged(data.colorScriptOption){},
        .demo_sub_chunks_sorter = chunk.subchunk.sorter.init(allocator),
    };
}

pub fn deinit() void {
    ui.demo_sub_chunks_sorter.deinit();
    ui.texture_script_options.deinit(ui.allocator);
    ui.block_options.deinit(ui.allocator);
    ui.chunk_script_options.deinit(ui.allocator);
    ui.terrain_gen_script_options.deinit(ui.allocator);
    ui.terrain_gen_script_options_available.deinit(ui.allocator);
    ui.terrain_gen_script_options_selected.deinit(ui.allocator);
    ui.world_managed_seed_terrain_scripts.deinit(ui.allocator);
    ui.world_options.deinit(ui.allocator);
    var td = ui.world_chunk_table_data.valueIterator();
    while (td.next()) |cc| {
        ui.allocator.free(cc.*.chunkData);
    }
    ui.world_chunk_table_data.deinit(ui.allocator);
    if (ui.texture_rgba_data) |d| ui.allocator.free(d);
    if (ui.texture_atlas_rgba_data) |d| ui.allocator.free(d);
    ui.allocator.destroy(ui);
}

const reference_height: f32 = 1080;
const reference_width: f32 = 1920;

pub fn setScreenSize(self: *UI, window: *glfw.Window) void {
    const s = window.getSize();
    self.screen_size = .{
        @floatFromInt(s[0]),
        @floatFromInt(s[1]),
    };
    const base_proggy_clean_font_size: f32 = 14;
    const base_roboto_font_size: f32 = 18;

    self.game_font = zgui.io.addFontFromMemory(
        proggyCleanFont,
        std.math.floor(
            base_proggy_clean_font_size * (self.screen_size[1] / reference_height),
        ),
    );
    self.code_font = zgui.io.addFontFromMemory(
        robotoMonoFont,
        std.math.floor(
            base_roboto_font_size * (self.screen_size[1] / reference_height),
        ),
    );
    zgui.io.setDefaultFont(self.game_font);
}

pub fn imguiWidth(self: *UI, w: f32) f32 {
    return std.math.floor(w * (self.screen_size[0] / reference_width));
}

pub fn imguiHeight(self: *UI, h: f32) f32 {
    return std.math.floor(h * (self.screen_size[1] / reference_height));
}

pub fn imguiX(self: *UI, x: f32) f32 {
    return std.math.floor(x * (self.screen_size[0] / reference_width));
}

pub fn imguiY(self: *UI, y: f32) f32 {
    return std.math.floor(y * (self.screen_size[1] / reference_height));
}

pub fn imguiButtonDims(self: *UI) [2]f32 {
    return .{
        self.imguiWidth(250),
        self.imguiHeight(50),
    };
}

pub fn imguiPadding(self: *UI) [2]f32 {
    return .{
        self.imguiWidth(5),
        self.imguiHeight(5),
    };
}

pub fn clearUISettingsState(self: *UI) void {
    self.terrain_gen_script_options_available.clearRetainingCapacity();
    self.terrain_gen_script_options_available.appendSlice(
        self.allocator,
        self.terrain_gen_script_options.items,
    ) catch @panic("OOM");
    self.terrain_gen_script_options_selected.clearRetainingCapacity();
}

fn swapScriptOptions(
    self: *UI,
    a: *std.ArrayListUnmanaged(data.colorScriptOption),
    b: *std.ArrayListUnmanaged(data.colorScriptOption),
    v: i32,
) void {
    var index: usize = 0;
    var i: usize = 0;
    while (i < a.items.len) : (i += 1) {
        index = i;
        if (a.items[i].id == v) break;
    }
    const so = a.swapRemove(index);
    b.append(self.allocator, so) catch @panic("OOM");
}

pub fn TerrainGenSelectScript(self: *UI, id: i32) void {
    self.swapScriptOptions(&self.terrain_gen_script_options_available, &self.terrain_gen_script_options_selected, id);
}

pub fn TerrainGenDeselectScript(self: *UI, id: i32) void {
    self.swapScriptOptions(&self.terrain_gen_script_options_selected, &self.terrain_gen_script_options_available, id);
}

const std = @import("std");
const zgui = @import("zgui");
const zm = @import("zmath");
const glfw = @import("zglfw");
const data = @import("../data/data.zig");
const script = @import("../script/script.zig");
const blecs = @import("../blecs/blecs.zig");
const block = @import("../block/block.zig");
const chunk = block.chunk;

pub const format = @import("ui_format.zig");
