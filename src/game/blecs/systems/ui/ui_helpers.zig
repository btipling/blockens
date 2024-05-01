pub const ScriptOptionsParams = struct {
    w: f32 = 0,
    h: f32 = 0,
};

pub fn scriptOptionsListBox(scriptOptions: std.ArrayList(data.chunkScriptOption), params: *ScriptOptionsParams) ?i32 {
    if (params.w == 0) params.w = game.state.ui.imguiWidth(250);
    if (params.h == 0) params.h = game.state.ui.imguiWidth(450);
    var rv: ?i32 = null;
    if (zgui.beginListBox("##chunk_script_options", .{
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

pub fn loadChunksInWorld() void {
    entities.screen.clearWorld();
    var instancedKeys = game.state.ui.world_chunk_table_data.keyIterator();
    while (instancedKeys.next()) |_k| {
        _ = game.state.jobs.copyChunk(_k.*, ecs.new_id(game.state.world), false, false);
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
const ui = @import("../../../ui.zig");
const script = @import("../../../script/script.zig");
const block = @import("../../../block/block.zig");
const chunk = block.chunk;
