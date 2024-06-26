const system_name = "UIBlockEditorSystem";

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, system_name, ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.BlockEditor) };
    desc.run = if (config.use_tracy) runWithTrace else run;
    return desc;
}

fn runWithTrace(it: *ecs.iter_t) callconv(.C) void {
    ztracy.Message(system_name);
    const tracy_zone = ztracy.ZoneNC(@src(), system_name, 0xff_00_ff_f0);
    defer tracy_zone.End();
    return run(it);
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = game.state.ui.imguiX(350);
            const yPos: f32 = game.state.ui.imguiY(25);
            zgui.setNextWindowPos(.{
                .x = xPos,
                .y = yPos,
                .cond = .first_use_ever,
            });
            zgui.setNextWindowSize(.{
                .w = game.state.ui.imguiWidth(1425),
                .h = game.state.ui.imguiHeight(1000),
                .cond = .first_use_ever,
            });
            if (zgui.begin("Block Editor", .{
                .flags = .{},
            })) {
                drawBlockOptions() catch |e| {
                    std.debug.print("error with drawBlockOptions: {}\n", .{e});
                };
                if (game.state.ui.block_loaded_block_id != 0) {
                    zgui.sameLine(.{});
                    drawBlockEditor() catch |e| {
                        std.debug.print("error with drawBlockEditor: {}\n", .{e});
                    };
                    zgui.sameLine(.{});
                    drawBlockConfig() catch |e| {
                        std.debug.print("error with drawBlockConfig: {}\n", .{e});
                    };
                }
            }
            zgui.end();
        }
    }
}

fn listBlocks() !void {
    try game.state.db.listBlocks(game.state.ui.allocator, &game.state.ui.block_options);
    for (game.state.ui.block_options.items) |bo| {
        if (!game.state.blocks.blocks.contains(bo.id)) {
            // detected a new block to load:
            entities.block.initBlock(bo.id);
        }
    }
    try listTextureScripts();
}

fn listTextureScripts() !void {
    try game.state.db.listTextureScripts(game.state.ui.allocator, &game.state.ui.texture_script_options);
}

fn saveBlock() !void {
    const n = std.mem.indexOf(u8, &game.state.ui.block_create_name_buf, &([_]u8{0}));
    if (n) |i| {
        if (i < 3) {
            std.log.err("Block name is too short", .{});
            return;
        }
    }
    // Reset these on save.
    game.state.ui.block_emits_light = false;
    game.state.ui.block_transparent = false;
    var emptyText = [_]u32{0} ** data.RGBAColorTextureSize;
    try game.state.db.saveBlock(
        &game.state.ui.block_create_name_buf,
        @ptrCast(&emptyText),
        false,
        0,
    );
    try listBlocks();
}

fn loadBlock(block_id: u8) !void {
    const b: *block.Block = game.state.blocks.blocks.get(block_id) orelse {
        std.debug.print("block with id {d} was not found\n", .{block_id});
        return;
    };
    var nameBuf = [_]u8{0} ** data.maxBlockSizeName;
    for (b.data.name, 0..) |c, i| {
        if (i >= data.maxBlockSizeName) {
            break;
        }
        nameBuf[i] = c;
    }
    // Settings texture data needs to be copied as it's owned separately
    const texture_rgba_data: []u32 = try game.state.allocator.alloc(u32, b.data.texture.len);
    @memcpy(texture_rgba_data, b.data.texture);

    game.state.ui.block_emits_light = false;
    if (b.data.light_level > 0) game.state.ui.block_emits_light = true;
    game.state.ui.block_transparent = b.data.transparent;
    std.debug.print("light: {d} transparent: {}\n", .{
        b.data.light_level,
        b.data.transparent,
    });
    game.state.ui.block_create_name_buf = nameBuf;
    game.state.ui.block_loaded_block_id = block_id;
    if (game.state.ui.texture_rgba_data) |d| game.state.allocator.free(d);
    game.state.ui.texture_rgba_data = texture_rgba_data;
    entities.screen.initDemoCube();
}

fn evalTextureFunc() !void {
    if (game.state.ui.texture_rgba_data) |d| game.state.allocator.free(d);
    game.state.ui.texture_rgba_data = try game.state.script.evalTextureFunc(game.state.ui.texture_buf);
    entities.screen.initDemoCube();
}

fn loadTextureScriptFunc(scriptId: i32) !void {
    var scriptData: data.script = undefined;
    try game.state.db.loadTextureScript(scriptId, &scriptData);
    var buf = [_]u8{0} ** script.maxLuaScriptSize;
    for (scriptData.script, 0..) |c, i| {
        if (i >= script.maxLuaScriptSize) {
            break;
        }
        buf[i] = c;
    }
    game.state.ui.texture_buf = buf;
    game.state.ui.texture_loaded_script_id = scriptId;
    try evalTextureFunc();
}

fn updateBlock() !void {
    const n = std.mem.indexOf(u8, &game.state.ui.block_create_name_buf, &([_]u8{0}));
    if (n) |i| {
        if (i < 3) {
            std.log.err("Block name is too short", .{});
            return;
        }
    }

    std.debug.print("light: {} transparent: {}\n", .{
        game.state.ui.block_emits_light,
        game.state.ui.block_transparent,
    });
    const texture_colors = game.state.ui.texture_rgba_data orelse return;
    var light_level: u8 = 0;
    if (game.state.ui.block_emits_light) light_level = 1;
    try game.state.db.updateBlock(
        game.state.ui.block_loaded_block_id,
        &game.state.ui.block_create_name_buf,
        texture_colors,
        game.state.ui.block_transparent,
        light_level,
    );
    // Need to update the game state blocks:
    entities.block.initBlock(game.state.ui.block_loaded_block_id);
    try listBlocks();
    try loadBlock(game.state.ui.block_loaded_block_id);
}

fn deleteBlock() !void {
    try game.state.db.deleteBlock(game.state.ui.block_loaded_block_id);
    entities.block.deinitBlock(game.state.ui.block_loaded_block_id);
    try listBlocks();
    game.state.ui.block_loaded_block_id = 0;
}

fn drawBlockOptions() !void {
    if (zgui.beginChild(
        "Saved Blocks",
        .{
            .w = game.state.ui.imguiWidth(425),
            .h = game.state.ui.imguiHeight(950),
            .border = true,
        },
    )) {
        try drawBlockList();
        try drawCreateForm();
    }
    zgui.endChild();
}

fn drawBlockConfig() !void {
    if (zgui.beginChild(
        "Configure Block",
        .{
            .w = game.state.ui.imguiWidth(900),
            .h = game.state.ui.imguiHeight(950),
            .border = true,
        },
    )) {
        if (zgui.checkbox("transparent", .{
            .v = &game.state.ui.block_transparent,
        })) {
            std.debug.print("transparent toggled light: {} transparent: {}\n", .{
                game.state.ui.block_emits_light,
                game.state.ui.block_transparent,
            });
        }
        if (zgui.checkbox("emits light", .{
            .v = &game.state.ui.block_emits_light,
        })) {
            std.debug.print("emits light toggled, light: {} transparent: {}\n", .{
                game.state.ui.block_emits_light,
                game.state.ui.block_transparent,
            });
        }
        zgui.endChild();
    }
}

fn drawBlockEditor() !void {
    const btn_dims: [2]f32 = game.state.ui.imguiButtonDims();
    if (zgui.beginChild(
        "Configure Block",
        .{
            .w = game.state.ui.imguiWidth(900),
            .h = game.state.ui.imguiHeight(950),
            .border = true,
        },
    )) {
        zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = game.state.ui.imguiPadding() });
        if (zgui.button("Update block", .{
            .w = btn_dims[0],
            .h = btn_dims[1],
        })) {
            try updateBlock();
        }
        zgui.popStyleVar(.{ .count = 1 });
        zgui.pushFont(game.state.ui.code_font);
        zgui.pushItemWidth(game.state.ui.imguiWidth(200));
        _ = zgui.inputTextWithHint("Name", .{
            .buf = game.state.ui.block_create_name_buf[0..],
            .hint = "block name",
        });
        if (zgui.button("Delete block", .{
            .w = btn_dims[0],
            .h = btn_dims[1],
        })) {
            try deleteBlock();
        }
        zgui.popItemWidth();
        zgui.popFont();
        zgui.text("Select a texture", .{});
        _ = zgui.beginListBox("##listbox", .{
            .w = game.state.ui.imguiWidth(400),
            .h = game.state.ui.imguiHeight(700),
        });
        for (game.state.ui.texture_script_options.items) |scriptOption| {
            var buffer: [script.maxLuaScriptNameSize + 10]u8 = undefined;
            const selectableName = try std.fmt.bufPrint(&buffer, "{d}: {s}", .{ scriptOption.id, scriptOption.name });
            var name: [script.maxLuaScriptNameSize:0]u8 = undefined;
            for (name, 0..) |_, i| {
                if (selectableName.len <= i) {
                    name[i] = 0;
                    break;
                }
                name[i] = selectableName[i];
            }
            if (zgui.selectable(&name, .{})) {
                try loadTextureScriptFunc(scriptOption.id);
            }
        }
        zgui.endListBox();
    }
    zgui.endChild();
}

fn drawBlockList() !void {
    const btn_dims: [2]f32 = game.state.ui.imguiButtonDims();
    if (zgui.beginChild(
        "Blocks",
        .{
            .w = game.state.ui.imguiWidth(425),
            .h = game.state.ui.imguiHeight(625),
            .border = false,
        },
    )) {
        if (zgui.button("Refresh list", .{
            .w = btn_dims[0],
            .h = btn_dims[1],
        })) {
            try listBlocks();
        }
        _ = zgui.beginListBox("##listbox", .{
            .w = game.state.ui.imguiWidth(400),
            .h = game.state.ui.imguiHeight(450),
        });

        for (game.state.ui.block_options.items) |blockOption| {
            var buffer: [data.maxBlockSizeName + 10]u8 = undefined;
            const selectableName = try std.fmt.bufPrint(&buffer, "{d}: {s}", .{ blockOption.id, blockOption.name });
            var name: [data.maxBlockSizeName:0]u8 = undefined;
            for (name, 0..) |_, i| {
                if (selectableName.len <= i) {
                    name[i] = 0;
                    break;
                }
                name[i] = selectableName[i];
            }
            if (zgui.selectable(&name, .{})) {
                try loadBlock(blockOption.id);
            }
        }
        zgui.endListBox();
        if (game.state.ui.block_loaded_block_id != 0) {
            if (zgui.button("Update block", .{
                .w = btn_dims[0],
                .h = btn_dims[1],
            })) {
                try updateBlock();
            }
            if (zgui.button("Delete block", .{
                .w = btn_dims[0],
                .h = btn_dims[1],
            })) {
                try deleteBlock();
            }
        }
    }
    zgui.endChild();
}

fn drawCreateForm() !void {
    const btn_dims: [2]f32 = game.state.ui.imguiButtonDims();
    if (zgui.beginChild(
        "Create Block",
        .{
            .w = game.state.ui.imguiWidth(425),
            .h = game.state.ui.imguiHeight(250),
            .border = false,
        },
    )) {
        zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = game.state.ui.imguiPadding() });
        if (zgui.button("Create block", .{
            .w = btn_dims[0],
            .h = btn_dims[1],
        })) {
            try saveBlock();
        }
        zgui.popStyleVar(.{ .count = 1 });
        zgui.pushFont(game.state.ui.code_font);
        zgui.pushItemWidth(game.state.ui.imguiWidth(200));
        _ = zgui.inputTextWithHint("Name", .{
            .buf = game.state.ui.block_create_name_buf[0..],
            .hint = "block name",
        });
        zgui.popItemWidth();
        zgui.popFont();
    }
    zgui.endChild();
}

const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const ztracy = @import("ztracy");
const config = @import("config");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const data = @import("../../../data/data.zig");
const script = @import("../../../script/script.zig");
const block = @import("../../../block/block.zig");
