const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const gl = @import("zopengl").bindings;
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const data = @import("../../../data/data.zig");
const script = @import("../../../script/script.zig");
const menus = @import("../../../ui/menus.zig");
const screen_helpers = @import("../screen_helpers.zig");

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
            const xPos: f32 = 1200.0;
            const yPos: f32 = 50.0;
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = 2600,
                .h = 2000,
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
    if (zgui.beginChild(
        "Create World",
        .{
            .w = 700,
            .h = 1950,
            .border = false,
        },
    )) {
        zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
        if (zgui.button("Generate chunk", .{
            .w = 500,
            .h = 75,
        })) {
            try evalChunkFunc();
        }
        if (zgui.button("Toggle wireframe", .{
            .w = 500,
            .h = 75,
        })) {
            toggleWireframe();
        }
        zgui.text("Chunk xyz:", .{});
        zgui.sameLine(.{});
        zgui.pushItemWidth(75);
        _ = zgui.inputTextWithHint("##chunkXPos", .{
            .buf = game.state.ui.data.chunk_x_buf[0..],
            .hint = "x",
        });
        zgui.sameLine(.{});
        _ = zgui.inputTextWithHint("##chunkYPos", .{
            .buf = game.state.ui.data.chunk_y_buf[0..],
            .hint = "y",
        });
        zgui.sameLine(.{});
        _ = zgui.inputTextWithHint("##chunkZPos", .{
            .buf = game.state.ui.data.chunk_z_buf[0..],
            .hint = "z",
        });
        zgui.popItemWidth();
        if (zgui.button("Generate to world", .{
            .w = 500,
            .h = 75,
        })) {
            try evalWorldChunkFunc();
        }
        if (zgui.colorEdit3("##Script color", .{
            .col = &game.state.ui.data.chunk_script_color,
            .flags = .{
                .picker_hue_bar = true,
            },
        })) {}
        zgui.pushFont(game.state.ui.codeFont);
        zgui.pushItemWidth(500);
        _ = zgui.inputTextWithHint("##script name", .{
            .buf = game.state.ui.data.chunk_name_buf[0..],
            .hint = "chunk_script",
        });
        zgui.popItemWidth();
        zgui.popFont();
        if (zgui.button("Create script", .{
            .w = 500,
            .h = 75,
        })) {
            try saveChunkScriptFunc();
        }
        if (zgui.button("Update script", .{
            .w = 500,
            .h = 75,
        })) {
            try updateChunkScriptFunc();
        }
        if (zgui.button("Delete script", .{
            .w = 500,
            .h = 75,
        })) {
            try deleteChunkScriptFunc();
        }
        if (zgui.button("Refresh list", .{
            .w = 500,
            .h = 100,
        })) {
            try listChunkScripts();
        }
        zgui.popStyleVar(.{ .count = 1 });
        if (menus.scriptOptionsListBox(game.state.ui.data.chunk_script_options, .{})) |scriptOptionId| {
            try loadChunkScriptFunc(scriptOptionId);
        }
    }
    zgui.endChild();
}

fn drawInput() !void {
    if (zgui.beginChild(
        "script_input",
        .{
            .w = 1800,
            .h = 1950,
            .border = true,
        },
    )) {
        zgui.pushFont(game.state.ui.codeFont);
        _ = zgui.inputTextMultiline(" ", .{
            .buf = game.state.ui.data.chunk_buf[0..],
            .w = 1784,
            .h = 1900,
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
    ) orelse unreachable;
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
    const chunk_data = try game.state.script.evalChunkFunc(game.state.ui.data.chunk_buf);
    const x = floatFromChunkBuf(&game.state.ui.data.chunk_x_buf);
    const y = floatFromChunkBuf(&game.state.ui.data.chunk_y_buf);
    const z = floatFromChunkBuf(&game.state.ui.data.chunk_z_buf);
    std.debug.print("Writing chunk to world at position: {}, {}, {}\n", .{ x, y, z });
    if (game.state.ui.data.chunk_demo_data) |d| game.state.allocator.free(d);
    game.state.ui.data.chunk_demo_data = chunk_data;
}

fn listChunkScripts() !void {
    try game.state.db.listChunkScripts(&game.state.ui.data.chunk_script_options);
}

fn loadChunkScriptFunc(scriptId: i32) !void {
    var scriptData: data.chunkScript = undefined;
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
    game.state.ui.data.chunk_buf = script.Script.dataScriptToScript(scriptData.script);
    game.state.ui.data.chunk_name_buf = nameBuf;
    game.state.ui.data.chunk_script_color = scriptData.color;
    try evalChunkFunc();
    game.state.ui.data.chunk_loaded_script_id = scriptId;
}

fn saveChunkScriptFunc() !void {
    const n = std.mem.indexOf(u8, &game.state.ui.data.chunk_name_buf, &([_]u8{0}));
    if (n) |i| {
        if (i < 3) {
            std.log.err("Script name is too short", .{});
            return;
        }
    }
    try game.state.db.saveChunkScript(&game.state.ui.data.chunk_name_buf, &game.state.ui.data.chunk_buf, game.state.ui.data.chunk_script_color);
    try listChunkScripts();
}

fn updateChunkScriptFunc() !void {
    const n = std.mem.indexOf(u8, &game.state.ui.data.chunk_name_buf, &([_]u8{0}));
    if (n) |i| {
        if (i < 3) {
            std.log.err("Script name is too short", .{});
            return;
        }
    }
    try game.state.db.updateChunkScript(game.state.ui.data.chunk_loaded_script_id, &game.state.ui.data.chunk_name_buf, &game.state.ui.data.chunk_buf, game.state.ui.data.chunk_script_color);
    try listChunkScripts();
    try loadChunkScriptFunc(game.state.ui.data.chunk_loaded_script_id);
}

fn deleteChunkScriptFunc() !void {
    try game.state.db.deleteChunkScript(game.state.ui.data.chunk_loaded_script_id);
    try listChunkScripts();
    game.state.ui.data.chunk_loaded_script_id = 0;
}
