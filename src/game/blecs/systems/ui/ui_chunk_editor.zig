pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UIChunkEditorSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.ChunkEditor) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = game.state.ui.imguiX(600);
            const yPos: f32 = game.state.ui.imguiY(25);
            zgui.setNextWindowPos(.{
                .x = xPos,
                .y = yPos,
                .cond = .first_use_ever,
            });
            zgui.setNextWindowSize(.{
                .w = game.state.ui.imguiWidth(1300),
                .h = game.state.ui.imguiHeight(1000),
                .cond = .first_use_ever,
            });
            if (zgui.begin("Chunk Editor", .{
                .flags = .{},
            })) {
                drawInput() catch |e| {
                    std.debug.print("error with draw chunk editor input: {}\n", .{e});
                };
                zgui.sameLine(.{});
                drawControls() catch |e| {
                    std.debug.print("error with draw controls in chunk editor: {}\n", .{e});
                };
            }
            zgui.end();
        }
    }
}

fn drawControls() !void {
    const btn_dms: [2]f32 = game.state.ui.imguiButtonDims();
    if (zgui.beginChild(
        "Create Chunk",
        .{
            .w = game.state.ui.imguiWidth(350),
            .h = game.state.ui.imguiHeight(975),
            .border = false,
        },
    )) {
        zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = game.state.ui.imguiPadding() });
        if (zgui.button("Generate chunk", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try evalChunkFunc();
        }
        if (zgui.button("Toggle wireframe", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            toggleWireframe();
        }
        zgui.text("Chunk xyz:", .{});
        zgui.sameLine(.{});
        zgui.pushItemWidth(game.state.ui.imguiWidth(35));
        _ = zgui.inputTextWithHint("##chunkXPos", .{
            .buf = game.state.ui.chunk_x_buf[0..],
            .hint = "x",
        });
        zgui.sameLine(.{});
        _ = zgui.inputTextWithHint("##chunkYPos", .{
            .buf = game.state.ui.chunk_y_buf[0..],
            .hint = "y",
        });
        zgui.sameLine(.{});
        _ = zgui.inputTextWithHint("##chunkZPos", .{
            .buf = game.state.ui.chunk_z_buf[0..],
            .hint = "z",
        });
        zgui.popItemWidth();
        if (zgui.button("Generate to world", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try evalWorldChunkFunc();
        }
        if (zgui.colorEdit3("##Script color", .{
            .col = &game.state.ui.chunk_script_color,
            .flags = .{
                .picker_hue_bar = true,
            },
        })) {}
        zgui.pushFont(game.state.ui.codeFont);
        zgui.pushItemWidth(game.state.ui.imguiWidth(250));
        _ = zgui.inputTextWithHint("##script name", .{
            .buf = game.state.ui.chunk_name_buf[0..],
            .hint = "chunk_script",
        });
        zgui.popItemWidth();
        zgui.popFont();
        if (zgui.button("Create script", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try saveChunkScriptFunc();
        }
        if (zgui.button("Update script", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try updateChunkScriptFunc();
        }
        if (zgui.button("Delete script", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try deleteChunkScriptFunc();
        }
        if (zgui.button("Refresh list", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try listChunkScripts();
        }
        zgui.popStyleVar(.{ .count = 1 });
        var params: helpers.ScriptOptionsParams = .{};
        if (helpers.scriptOptionsListBox(game.state.ui.chunk_script_options, &params)) |scriptOptionId| {
            try loadChunkScriptFunc(scriptOptionId);
        }
    }
    zgui.endChild();
}

fn drawInput() !void {
    if (zgui.beginChild(
        "script_input",
        .{
            .w = game.state.ui.imguiWidth(900),
            .h = game.state.ui.imguiHeight(975),
            .border = true,
        },
    )) {
        zgui.pushFont(game.state.ui.codeFont);
        _ = zgui.inputTextMultiline("##chunk_gen_input", .{
            .buf = game.state.ui.chunk_buf[0..],
            .w = game.state.ui.imguiWidth(884),
            .h = game.state.ui.imguiHeight(950),
        });
        zgui.popFont();
    }
    zgui.endChild();
}

fn toggleWireframe() void {
    const screen: *const components.screen.Screen = ecs.get(
        game.state.world,
        game.state.entities.screen,
        components.screen.Screen,
    ) orelse return;
    screen_helpers.toggleWireframe(screen.current);
}

fn evalChunkFunc() !void {
    _ = game.state.jobs.generateDemoChunk();
}

fn floatFromChunkBuf(buf: []u8) f32 {
    const r = [_]u8{0};
    const b = std.mem.trim(u8, buf, &r);
    return std.fmt.parseFloat(f32, b) catch |err| {
        std.debug.print("Error parsing chunk position: {}\n", .{err});
        return 0.0;
    };
}

fn evalWorldChunkFunc() !void {
    const x = floatFromChunkBuf(&game.state.ui.chunk_x_buf);
    const y = floatFromChunkBuf(&game.state.ui.chunk_y_buf);
    const z = floatFromChunkBuf(&game.state.ui.chunk_z_buf);
    std.debug.print("Writing chunk to world at position: {}, {}, {}\n", .{ x, y, z });
    const p = @Vector(4, f32){ x, y, z, 0 };
    const wp = chunk.worldPosition.initFromPositionV(p);
    _ = game.state.jobs.generateWorldChunk(wp, &game.state.ui.chunk_buf);
}

fn listChunkScripts() !void {
    try game.state.db.listChunkScripts(game.state.ui.allocator, &game.state.ui.chunk_script_options);
}

fn loadChunkScriptFunc(scriptId: i32) !void {
    var scriptData: data.colorScript = undefined;
    game.state.db.loadChunkScript(scriptId, &scriptData) catch |err| {
        if (err != data.DataErr.NotFound) {
            return err;
        }
        return;
    };
    var nameBuf = [_]u8{0} ** script.maxLuaScriptNameSize;
    for (scriptData.name, 0..) |c, i| {
        if (i >= script.maxLuaScriptNameSize) {
            break;
        }
        nameBuf[i] = c;
    }
    game.state.ui.chunk_buf = script.utils.dataScriptToScript(scriptData.script);
    game.state.ui.chunk_name_buf = nameBuf;
    game.state.ui.chunk_script_color = scriptData.color;
    try evalChunkFunc();
    game.state.ui.chunk_loaded_script_id = scriptId;
}

fn saveChunkScriptFunc() !void {
    const n = std.mem.indexOf(u8, &game.state.ui.chunk_name_buf, &([_]u8{0}));
    if (n) |i| {
        if (i < 3) {
            std.log.err("Script name is too short", .{});
            return;
        }
    }
    try game.state.db.saveChunkScript(&game.state.ui.chunk_name_buf, &game.state.ui.chunk_buf, game.state.ui.chunk_script_color);
    try listChunkScripts();
}

fn updateChunkScriptFunc() !void {
    const n = std.mem.indexOf(u8, &game.state.ui.chunk_name_buf, &([_]u8{0}));
    if (n) |i| {
        if (i < 3) {
            std.log.err("Script name is too short", .{});
            return;
        }
    }
    try game.state.db.updateChunkScript(game.state.ui.chunk_loaded_script_id, &game.state.ui.chunk_name_buf, &game.state.ui.chunk_buf, game.state.ui.chunk_script_color);
    try listChunkScripts();
    try loadChunkScriptFunc(game.state.ui.chunk_loaded_script_id);
}

fn deleteChunkScriptFunc() !void {
    try game.state.db.deleteChunkScript(game.state.ui.chunk_loaded_script_id);
    try listChunkScripts();
    game.state.ui.chunk_loaded_script_id = 0;
}

const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const data = @import("../../../data/data.zig");
const state = @import("../../../state.zig");
const script = @import("../../../script/script.zig");
const helpers = @import("ui_helpers.zig");
const screen_helpers = @import("../screen_helpers.zig");
const block = @import("../../../block/block.zig");
const chunk = block.chunk;
