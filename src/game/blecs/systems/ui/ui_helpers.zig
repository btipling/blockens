pub const ScriptOptionsParams = struct {
    w: f32 = 0,
    h: f32 = 0,
};

pub fn scriptOptionsListBox(id: [:0]const u8, scriptOptions: std.ArrayListUnmanaged(data.colorScriptOption), params: *ScriptOptionsParams) ?i32 {
    if (params.w == 0) params.w = game.state.ui.imguiWidth(250);
    if (params.h == 0) params.h = game.state.ui.imguiWidth(450);
    var rv: ?i32 = null;
    if (zgui.beginListBox(id, .{
        .w = params.w,
        .h = params.h,
    })) {
        zgui.pushStyleColor4f(.{ .idx = .header_hovered, .c = .{ 1.0, 1.0, 1.0, 0.25 } });
        for (scriptOptions.items) |scriptOption| {
            var buffer: [script.maxLuaScriptNameSize + 10]u8 = undefined;

            var sn = scriptOption.name;
            var st: usize = 0;
            for (0..scriptOption.name.len) |i| {
                if (scriptOption.name[i] == 0) {
                    st = i;
                    break;
                }
            }
            if (st == 0) {
                break;
            }
            var name = std.fmt.bufPrintZ(&buffer, "  {d}: {s}", .{ scriptOption.id, sn[0..st :0] }) catch {
                std.debug.print("unable to write selectable name.\n", .{});
                continue;
            };
            _ = &name;
            var dl = zgui.getWindowDrawList();
            const pmin = zgui.getCursorScreenPos();
            const pmax = [2]f32{
                pmin[0] + game.state.ui.imguiWidth(10),
                pmin[1] + game.state.ui.imguiHeight(10),
            };
            const col = zgui.colorConvertFloat4ToU32(.{ scriptOption.color[0], scriptOption.color[1], scriptOption.color[2], 1.0 });
            dl.addRectFilled(.{ .pmin = pmin, .pmax = pmax, .col = col });

            if (zgui.selectable(name, .{ .h = game.state.ui.imguiHeight(30) })) {
                rv = scriptOption.id;
            }
        }
        zgui.popStyleColor(.{ .count = 1 });
        zgui.endListBox();
    }
    return rv;
}

pub const worldChoice = struct {
    world_id: i32 = 0,
    name: [ui.max_world_name:0]u8,
};

pub fn worldChooser(sel: worldChoice) ?worldChoice {
    var choice: ?worldChoice = null;
    var combo: bool = false;
    var cw: bool = false;
    for (game.state.ui.world_options.items, 0..) |world_opt, i| {
        var buffer: [ui.max_world_name + 10]u8 = std.mem.zeroes([ui.max_world_name + 10]u8);
        const selectable_name = std.fmt.bufPrint(
            &buffer,
            "{d}: {s}",
            .{ world_opt.id, world_opt.name },
        ) catch @panic("invalid buffer size");
        var name: [ui.max_world_name:0]u8 = undefined;
        for (name, 0..) |_, ii| {
            if (selectable_name.len <= ii) {
                name[ii] = 0;
                break;
            }
            name[ii] = selectable_name[ii];
        }
        const loaded_world_id = sel.world_id;
        if (i == 0) {
            var preview_name: [:0]const u8 = &sel.name;
            if (loaded_world_id == 0) {
                preview_name = "Choose";
            }
            zgui.setNextItemWidth(game.state.ui.imguiWidth(250));
            combo = zgui.beginCombo("##listbox", .{
                .preview_value = preview_name,
            });
            cw = zgui.beginPopupContextWindow();
        }
        if (combo) {
            const selected = world_opt.id == loaded_world_id;
            if (zgui.selectable(&name, .{ .selected = selected })) {
                if (world_opt.id != 0) {
                    var wc: worldChoice = .{
                        .world_id = world_opt.id,
                        .name = std.mem.zeroes([ui.max_world_name:0]u8),
                    };
                    @memcpy(wc.name[0..20], world_opt.name[0..20]);
                    choice = wc;
                }
            }
        }
    }
    if (cw) zgui.endPopup();
    if (combo) zgui.endCombo();
    return choice;
}

pub fn loadChunksInWorld(render_chunks: bool) void {
    entities.screen.clearWorld();
    var instancedKeys = game.state.ui.world_chunk_table_data.keyIterator();
    while (instancedKeys.next()) |k| {
        chunk.render.initGameChunk(k.*, ecs.new_id(game.state.world), false, render_chunks);
    }
}

pub fn loadCharacterInWorld() void {
    entities.screen.initPlayerCharacter();
    entities.screen.initBlockHighlight();
}

const std = @import("std");
const zgui = @import("zgui");
const ecs = @import("zflecs");
const config = @import("../../../config.zig");
const data = @import("../../../data/data.zig");
const game = @import("../../../game.zig");
const entities = @import("../../entities/entities.zig");
const ui = @import("../../../ui/ui.zig");
const script = @import("../../../script/script.zig");
const block = @import("../../../block/block.zig");
const chunk = block.chunk;
