const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const game = @import("../../../game.zig");
const data = @import("../../../data/data.zig");
const script = @import("../../../script/script.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UITextureGenSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.TextureGen) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = game.state.ui.imguiX(350);
            const yPos: f32 = game.state.ui.imguiY(25);
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = game.state.ui.imguiWidth(1425),
                .h = game.state.ui.imguiHeight(1000),
            });
            if (zgui.begin("Texture Editor", .{
                .flags = .{},
            })) {
                drawInput() catch |e| {
                    std.debug.print("error with input: {}\n", .{e});
                };
                zgui.sameLine(.{});
                drawScriptList() catch |e| {
                    std.debug.print("error with drawScriptList: {}\n", .{e});
                };
            }
            zgui.end();
        }
    }
}

fn drawInput() !void {
    if (zgui.beginChild(
        "script_input",
        .{
            .w = game.state.ui.imguiWidth(1000),
            .h = game.state.ui.imguiHeight(1000),
            .border = true,
        },
    )) {
        const btn_dms: [2]f32 = game.state.ui.imguiButtonDims();
        zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
        if (zgui.button("Change texture", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try evalTextureFunc();
        }
        zgui.sameLine(.{});
        if (zgui.button("Save new script", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try saveTextureScriptFunc();
        }
        zgui.popStyleVar(.{ .count = 1 });
        zgui.sameLine(.{});
        zgui.pushFont(game.state.ui.codeFont);
        zgui.pushItemWidth(game.state.ui.imguiWidth(500));
        _ = zgui.inputTextWithHint("Script name", .{
            .buf = @ptrCast(&game.state.ui.texture_name_buf),
            .hint = "block_script",
        });
        zgui.popItemWidth();
        _ = zgui.inputTextMultiline(" ", .{
            .buf = @ptrCast(&game.state.ui.texture_buf),
            .w = game.state.ui.imguiWidth(984),
            .h = game.state.ui.imguiHeight(1000),
        });
        zgui.popFont();
    }
    zgui.endChild();
}

fn drawScriptList() !void {
    const btn_dms: [2]f32 = game.state.ui.imguiButtonDims();
    if (zgui.beginChild(
        "Saved scripts",
        .{
            .w = game.state.ui.imguiWidth(410),
            .h = game.state.ui.imguiHeight(1000),
            .border = true,
        },
    )) {
        if (zgui.button("Refresh list", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try listTextureScripts();
        }
        _ = zgui.beginListBox("##listbox", .{
            .w = game.state.ui.imguiWidth(400),
            .h = game.state.ui.imguiHeight(700),
        });
        for (game.state.ui.texture_script_options.items) |scriptOption| {
            var buffer: [script.maxLuaScriptNameSize + 10]u8 = undefined;
            const selectableName = try std.fmt.bufPrint(&buffer, "{d}: {s}", .{
                scriptOption.id,
                scriptOption.name,
            });
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
        if (game.state.ui.texture_loaded_script_id != 0) {
            if (zgui.button("Update script", .{
                .w = btn_dms[0],
                .h = btn_dms[1],
            })) {
                try updateTextureScriptFunc();
            }
            if (zgui.button("Delete script", .{
                .w = btn_dms[0],
                .h = btn_dms[1],
            })) {
                try deleteTextureScriptFunc();
            }
        }
    }
    zgui.endChild();
}

fn listTextureScripts() !void {
    try game.state.db.listTextureScripts(&game.state.ui.texture_script_options);
}

fn loadTextureScriptFunc(scriptId: i32) !void {
    var scriptData: data.script = undefined;
    try game.state.db.loadTextureScript(scriptId, &scriptData);
    var buf = [_]u8{0} ** script.maxLuaScriptSize;
    var nameBuf = [_]u8{0} ** script.maxLuaScriptNameSize;
    for (scriptData.name, 0..) |c, i| {
        if (i >= script.maxLuaScriptNameSize) {
            break;
        }
        nameBuf[i] = c;
    }
    for (scriptData.script, 0..) |c, i| {
        if (i >= script.maxLuaScriptSize) {
            break;
        }
        buf[i] = c;
    }
    game.state.ui.texture_buf = buf;
    game.state.ui.texture_name_buf = nameBuf;
    try evalTextureFunc();
    game.state.ui.texture_loaded_script_id = scriptId;
}

fn evalTextureFunc() !void {
    if (game.state.ui.texture_rgba_data) |d| game.state.allocator.free(d);
    game.state.ui.texture_rgba_data = try game.state.script.evalTextureFunc(game.state.ui.texture_buf);
    entities.screen.initDemoCube();
}

fn saveTextureScriptFunc() !void {
    const n = std.mem.indexOf(u8, &game.state.ui.texture_name_buf, &([_]u8{0}));
    if (n) |i| {
        if (i < 3) {
            std.log.err("Script name is too short", .{});
            return;
        }
    }
    try game.state.db.saveTextureScript(
        &game.state.ui.texture_name_buf,
        &game.state.ui.texture_buf,
    );
    try listTextureScripts();
}

fn updateTextureScriptFunc() !void {
    const n = std.mem.indexOf(u8, &game.state.ui.texture_name_buf, &([_]u8{0}));
    if (n) |i| {
        if (i < 3) {
            std.log.err("Script name is too short", .{});
            return;
        }
    }
    try game.state.db.updateTextureScript(
        game.state.ui.texture_loaded_script_id,
        &game.state.ui.texture_name_buf,
        &game.state.ui.texture_buf,
    );
    try listTextureScripts();
    try loadTextureScriptFunc(game.state.ui.texture_loaded_script_id);
}

fn deleteTextureScriptFunc() !void {
    try game.state.db.deleteTextureScript(game.state.ui.texture_loaded_script_id);
    try listTextureScripts();
    game.state.ui.texture_loaded_script_id = 0;
}
