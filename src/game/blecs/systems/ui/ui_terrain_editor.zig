pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UITerrainEditorSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.TerrainEditor) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = game.state.ui.imguiX(1100);
            const yPos: f32 = game.state.ui.imguiY(25);
            zgui.setNextWindowPos(.{
                .x = xPos,
                .y = yPos,
                .cond = .first_use_ever,
            });
            zgui.setNextWindowSize(.{
                .w = game.state.ui.imguiWidth(800),
                .h = game.state.ui.imguiHeight(1000),
                .cond = .first_use_ever,
            });
            zgui.setNextItemWidth(-1);
            if (zgui.begin("Terrain Generator", .{
                .flags = .{},
            })) {
                drawInput() catch continue;
                zgui.sameLine(.{});
                drawControls() catch continue;
            }
            zgui.end();
        }
    }
}

fn drawControls() !void {
    const btn_dms: [2]f32 = game.state.ui.imguiButtonDims();
    if (zgui.beginChild(
        "Controls",
        .{},
    )) {
        zgui.text("terrain generator controls", .{});
        if (zgui.button("generate terrain", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            _ = game.state.jobs.generateDescriptor(
                game.state.ui.terrain_gen_x_buf,
                game.state.ui.terrain_gen_z_buf,
            );
        }

        if (zgui.sliderInt("seed", .{
            .v = &game.state.ui.terrain_gen_seed,
            .min = 0,
            .max = 100_000,
        })) {
            entities.screen.initDemoChunkCamera(false);
        }
        if (zgui.button("Toggle wireframe", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            toggleWireframe();
        }

        if (zgui.colorEdit3("##Script color", .{
            .col = &game.state.ui.terrain_gen_script_color,
            .flags = .{
                .picker_hue_bar = true,
            },
        })) {}
        zgui.pushFont(game.state.ui.codeFont);
        zgui.pushItemWidth(game.state.ui.imguiWidth(250));
        _ = zgui.inputTextWithHint("##script name", .{
            .buf = game.state.ui.terrain_gen_name_buf[0..],
            .hint = "terrain_gen_script",
        });
        zgui.popItemWidth();
        zgui.popFont();
        if (zgui.button("Create script", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try saveTerrainGenScriptFunc();
        }
        if (zgui.button("Update script", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try updateTerrainGenScriptFunc();
        }
        if (zgui.button("Delete script", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try deleteTerrainGenScriptFunc();
        }
        if (zgui.button("Refresh list", .{
            .w = btn_dms[0],
            .h = btn_dms[1],
        })) {
            try listTerrainGenScripts();
        }
        var params: helpers.ScriptOptionsParams = .{};
        if (helpers.scriptOptionsListBox(
            "#script_options_list",
            game.state.ui.terrain_gen_script_options,
            &params,
        )) |scriptOptionId| {
            try loadTerrainGenScriptFunc(scriptOptionId);
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
        _ = zgui.inputTextMultiline("##terrain_gen_input", .{
            .buf = game.state.ui.terrain_gen_buf[0..],
            .w = game.state.ui.imguiWidth(884),
            .h = game.state.ui.imguiHeight(950),
        });
        zgui.popFont();
    }
    zgui.endChild();
}

fn listTerrainGenScripts() !void {
    try game.state.db.listTerrainGenScripts(game.state.ui.allocator, &game.state.ui.terrain_gen_script_options);
}

fn loadTerrainGenScriptFunc(scriptId: i32) !void {
    var scriptData: data.colorScript = undefined;
    game.state.db.loadTerrainGenScript(scriptId, &scriptData) catch |err| {
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
    game.state.ui.terrain_gen_buf = script.utils.dataScriptToScript(scriptData.script);
    game.state.ui.terrain_gen_name_buf = nameBuf;
    game.state.ui.terrain_gen_script_color = scriptData.color;
    game.state.ui.terrain_gen_loaded_script_id = scriptId;
}

fn saveTerrainGenScriptFunc() !void {
    const n = std.mem.indexOf(u8, &game.state.ui.terrain_gen_name_buf, &([_]u8{0}));
    if (n) |i| {
        if (i < 3) {
            std.log.err("Script name is too short", .{});
            return;
        }
    }
    try game.state.db.saveTerrainGenScript(
        &game.state.ui.terrain_gen_name_buf,
        &game.state.ui.terrain_gen_buf,
        game.state.ui.terrain_gen_script_color,
    );
    try listTerrainGenScripts();
}

fn updateTerrainGenScriptFunc() !void {
    const n = std.mem.indexOf(u8, &game.state.ui.terrain_gen_name_buf, &([_]u8{0}));
    if (n) |i| {
        if (i < 3) {
            std.log.err("Script name is too short", .{});
            return;
        }
    }
    try game.state.db.updateTerrainGenScript(
        game.state.ui.terrain_gen_loaded_script_id,
        &game.state.ui.terrain_gen_name_buf,
        &game.state.ui.terrain_gen_buf,
        game.state.ui.terrain_gen_script_color,
    );
    try listTerrainGenScripts();
    try loadTerrainGenScriptFunc(game.state.ui.terrain_gen_loaded_script_id);
}

fn deleteTerrainGenScriptFunc() !void {
    try game.state.db.deleteTerrainGenScript(game.state.ui.terrain_gen_loaded_script_id);
    try listTerrainGenScripts();
    game.state.ui.terrain_gen_loaded_script_id = 0;
}

fn toggleWireframe() void {
    const screen: *const components.screen.Screen = ecs.get(
        game.state.world,
        game.state.entities.screen,
        components.screen.Screen,
    ) orelse return;
    screen_helpers.toggleWireframe(screen.current);
}

const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const entities = @import("../../entities/entities.zig");
const helpers = @import("ui_helpers.zig");
const screen_helpers = @import("../screen_helpers.zig");
const game = @import("../../../game.zig");
const data = @import("../../../data/data.zig");
const script = @import("../../../script/script.zig");
