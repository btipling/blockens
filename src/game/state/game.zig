const std = @import("std");
const glfw = @import("zglfw");
const ecs = @import("zflecs");
const gl = @import("zopengl");
const zm = @import("zmath");
const zgui = @import("zgui");

pub const Entities = struct {
    screen: usize = 0,
    clock: usize = 0,
    gfx: usize = 0,
    sky: usize = 0,
    floor: usize = 0,
    crosshair: usize = 0,
    menu: usize = 0,
};

pub const Input = struct {
    last_key: i64 = 0,
    last_x: f64 = 0,
    last_y: f64 = 0,
};

pub const UI = struct {
    gameFont: zgui.Font = undefined,
    codeFont: zgui.Font = undefined,
};

pub const ElementsRendererConfig = struct {
    vertexShader: [:0]const u8 = undefined,
    fragmentShader: [:0]const u8 = undefined,
    positions: [][3]gl.Float = undefined,
    indices: []u32 = undefined,
    transform: ?zm.Mat = null,
    ubo_binding_point: ?gl.Uint = null,
};

pub const Gfx = struct {
    ubos: std.AutoHashMap(gl.Uint, gl.Uint) = undefined,
    renderConfigs: std.AutoHashMap(ecs.entity_t, *ElementsRendererConfig) = undefined,
};

pub const Game = struct {
    allocator: std.mem.Allocator = undefined,
    window: *glfw.Window = undefined,
    world: *ecs.world_t = undefined,
    entities: Entities = .{},
    input: Input = .{},
    ui: UI = .{},
    gfx: Gfx = .{},
    quit: bool = false,
};
