pub const max_world_name = 20;

const robotoMonoFont = @embedFile("assets/fonts/Roboto_Mono/RobotoMono-Regular.ttf");
const proggyCleanFont = @embedFile("assets/fonts/ProggyClean/ProggyClean.ttf");

pub const chunkConfig = struct {
    id: i32 = 0, // from sqlite
    scriptId: i32,
    chunkData: []u32 = undefined,
};

gameFont: zgui.Font = undefined,
codeFont: zgui.Font = undefined,

texture_script_options: std.ArrayList(data.scriptOption) = undefined,
texture_loaded_script_id: i32 = 0,
texture_buf: [script.maxLuaScriptSize]u8 = std.mem.zeroes([script.maxLuaScriptSize]u8),
texture_name_buf: [script.maxLuaScriptNameSize]u8 = std.mem.zeroes([script.maxLuaScriptNameSize]u8),
texture_rgba_data: ?[]u32 = null,
texture_atlas_rgba_data: ?[]u32 = null,
texture_atlas_block_index: [blecs.entities.block.MaxBlocks]usize = std.mem.zeroes([blecs.entities.block.MaxBlocks]usize),
texture_atlas_num_blocks: usize = 0,

block_options: std.ArrayList(data.blockOption) = undefined,
block_create_name_buf: [data.maxBlockSizeName]u8 = std.mem.zeroes([data.maxBlockSizeName]u8),
block_update_name_buf: [data.maxBlockSizeName]u8 = std.mem.zeroes([data.maxBlockSizeName]u8),
block_emits_light: bool = false,
block_transparent: bool = false,
block_loaded_block_id: u8 = 0,

display_settings_fullscreen: bool = false,
display_settings_maximized: bool = true,
display_settings_decorated: bool = false,
display_settings_width: i32 = 0,
display_settings_height: i32 = 0,

chunk_name_buf: [script.maxLuaScriptNameSize]u8 = std.mem.zeroes([script.maxLuaScriptNameSize]u8),
chunk_buf: [script.maxLuaScriptSize]u8 = std.mem.zeroes([script.maxLuaScriptSize]u8),
chunk_x_buf: [5]u8 = std.mem.zeroes([5]u8),
chunk_y_buf: [5]u8 = std.mem.zeroes([5]u8),
chunk_z_buf: [5]u8 = std.mem.zeroes([5]u8),
chunk_script_options: std.ArrayList(data.chunkScriptOption) = undefined,
chunk_loaded_script_id: i32 = 0,
chunk_script_color: [3]f32 = std.mem.zeroes([3]f32),
chunk_demo_data: ?[]u32 = null,

world_name_buf: [max_world_name]u8 = std.mem.zeroes([max_world_name]u8),
world_options: std.ArrayList(data.worldOption) = undefined,
world_chunk_table_data: std.AutoHashMap(chunk.worldPosition, chunkConfig) = undefined,
world_loaded_name: [max_world_name:0]u8 = std.mem.zeroes([max_world_name:0]u8),
world_loaded_id: i32 = 0,
world_chunk_y: i32 = 0,
world_player_relocation: @Vector(4, f32) = .{ 32, 64, 32, 0 },
world_current_chunk: @Vector(4, f32) = undefined,

demo_cube_rotation: @Vector(4, f32) = zm.matToQuat(zm.rotationY(0 * std.math.pi)),
demo_cube_translation: @Vector(4, f32) = @Vector(4, f32){ 0, 0, 0, 0 },
demo_cube_pp_translation: @Vector(4, f32) = @Vector(4, f32){ -0.825, 0.650, 0, 0 },
demo_cube_plane_1_tl: @Vector(4, f32) = @Vector(4, f32){ -0.926, 0.12, 0, 0 },
demo_cube_plane_1_t2: @Vector(4, f32) = @Vector(4, f32){ -0.727, 0.090, 0, 0 },
demo_cube_plane_1_t3: @Vector(4, f32) = @Vector(4, f32){ -0.926, -0.54, 0, 0 },
demo_atlas_scale: @Vector(4, f32) = @Vector(4, f32){ 0.100, 1.940, 1, 0 },
demo_atlas_translation: @Vector(4, f32) = @Vector(4, f32){ -0.976, -0.959, 0, 0 },
demo_atlas_rotation: f32 = 0.5,
demo_chunk_rotation_x: f32 = 0,
demo_chunk_rotation_y: f32 = 0.341,
demo_chunk_rotation_z: f32 = 0.083,
demo_chunk_scale: f32 = 0.042,
demo_chunk_translation: @Vector(4, f32) = @Vector(4, f32){
    2.55,
    0.660,
    -0.264,
    0,
},
demo_chunk_pp_translation: @Vector(4, f32) = @Vector(4, f32){
    -0.650,
    0.100,
    0,
    0,
},

demo_character_rotation_x: f32 = 0.500,
demo_character_rotation_y: f32 = 0.536,
demo_character_rotation_z: f32 = 0.501,
demo_character_scale: f32 = 0.235,
demo_character_translation: @Vector(4, f32) = @Vector(4, f32){
    -7.393,
    -0.293,
    -0.060,
    0,
},
demo_character_pp_translation: @Vector(4, f32) = @Vector(4, f32){
    -0.259,
    0.217,
    0,
    0,
},

load_percentage_lighting_initial: f16 = 0,
load_percentage_lighting_cross_chunk: f16 = 0,
load_percentage_load_chunks: f16 = 0,

screen_size: [2]f32 = .{ 0, 0 },

const UI = @This();
pub var ui: *UI = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    ui = allocator.create(UI) catch @panic("OOM");

    ui.* = .{
        .texture_script_options = std.ArrayList(data.scriptOption).init(allocator),
        .block_options = std.ArrayList(data.blockOption).init(allocator),
        .chunk_script_options = std.ArrayList(data.chunkScriptOption).init(allocator),
        .world_options = std.ArrayList(data.worldOption).init(allocator),
        .world_chunk_table_data = std.AutoHashMap(chunk.worldPosition, chunkConfig).init(allocator),
    };
}

pub fn deinit(allocator: std.mem.Allocator) void {
    ui.texture_script_options.deinit();
    ui.block_options.deinit();
    ui.chunk_script_options.deinit();
    ui.world_options.deinit();
    var td = ui.world_chunk_table_data.valueIterator();
    while (td.next()) |cc| {
        allocator.free(cc.*.chunkData);
    }
    ui.world_chunk_table_data.deinit();
    if (ui.texture_rgba_data) |d| allocator.free(d);
    if (ui.texture_atlas_rgba_data) |d| allocator.free(d);
    if (ui.chunk_demo_data) |d| allocator.free(d);
    allocator.destroy(ui);
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

    self.gameFont = zgui.io.addFontFromMemory(
        proggyCleanFont,
        std.math.floor(
            base_proggy_clean_font_size * (self.screen_size[1] / reference_height),
        ),
    );
    self.codeFont = zgui.io.addFontFromMemory(
        robotoMonoFont,
        std.math.floor(
            base_roboto_font_size * (self.screen_size[1] / reference_height),
        ),
    );
    zgui.io.setDefaultFont(self.gameFont);
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

const std = @import("std");
const zgui = @import("zgui");
const zm = @import("zmath");
const glfw = @import("zglfw");
const data = @import("data/data.zig");
const script = @import("script/script.zig");
const blecs = @import("blecs/blecs.zig");
const block = @import("block/block.zig");
const chunk = block.chunk;
