const std = @import("std");
const ecs = @import("zflecs");
const zgui = @import("zgui");
const gl = @import("zopengl");
const glfw = @import("zglfw");
const components = @import("../../components/components.zig");
const game = @import("../../../game.zig");
const screen_helpers = @import("../../../screen/screen.zig");

pub fn init() void {
    const s = system();
    ecs.SYSTEM(game.state.world, "UITextureGenSystem", ecs.OnStore, @constCast(&s));
}

fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.screen.texture_gen.TextureGen) };
    desc.run = run;
    return desc;
}

fn run(it: *ecs.iter_t) callconv(.C) void {
    while (ecs.iter_next(it)) {
        for (0..it.count()) |_| {
            const xPos: f32 = 700.0;
            const yPos: f32 = 50.0;
            zgui.setNextWindowPos(.{ .x = xPos, .y = yPos, .cond = .always });
            zgui.setNextWindowSize(.{
                .w = 2850,
                .h = 2000,
            });
            zgui.setNextItemWidth(-1);
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
            .w = 2000,
            .h = 2000,
            .border = true,
        },
    )) {
        zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = [2]f32{ 10.0, 10.0 } });
        if (zgui.button("Change texture", .{
            .w = 450,
            .h = 100,
        })) {
            std.debug.print("eval texture list\n", .{});
        }
        zgui.sameLine(.{});
        if (zgui.button("Save new texture script", .{
            .w = 650,
            .h = 100,
        })) {
            std.debug.print("save textur\n", .{});
        }
        zgui.popStyleVar(.{ .count = 1 });
        zgui.sameLine(.{});
        zgui.pushFont(game.state.ui.codeFont);
        zgui.pushItemWidth(1000);
        var nameBuf: [1000:0]u8 = [_:0]u8{0} ** 1000;
        var buf: [1000:0]u8 = [_:0]u8{0} ** 1000;
        _ = zgui.inputTextWithHint("Script name", .{
            .buf = @ptrCast(&nameBuf),
            .hint = "block_script",
        });
        zgui.popItemWidth();
        _ = zgui.inputTextMultiline(" ", .{
            .buf = @ptrCast(&buf),
            .w = 1984,
            .h = 1840,
        });
        zgui.popFont();
    }
    zgui.endChild();
}

fn drawScriptList() !void {
    if (zgui.beginChild(
        "Saved scripts",
        .{
            .w = 850,
            .h = 1800,
            .border = true,
        },
    )) {
        if (zgui.button("Refresh list", .{
            .w = 450,
            .h = 100,
        })) {
            std.debug.print("list texture scripts\n", .{});
        }
        _ = zgui.beginListBox("##listbox", .{
            .w = 800,
            .h = 1400,
        });
        // for (self.scriptOptions.items) |scriptOption| {
        //     var buffer: [script.maxLuaScriptNameSize + 10]u8 = undefined;
        //     const selectableName = try std.fmt.bufPrint(&buffer, "{d}: {s}", .{ scriptOption.id, scriptOption.name });
        //     var name: [script.maxLuaScriptNameSize:0]u8 = undefined;
        //     for (name, 0..) |_, i| {
        //         if (selectableName.len <= i) {
        //             name[i] = 0;
        //             break;
        //         }
        //         name[i] = selectableName[i];
        //     }
        //     if (zgui.selectable(&name, .{})) {
        //         try self.loadTextureScriptFunc(scriptOption.id);
        //     }
        // }
        zgui.endListBox();
        if (false) {
            if (zgui.button("Update script", .{
                .w = 450,
                .h = 100,
            })) {
                std.debug.print("update texture script\n", .{});
            }
            if (zgui.button("Delete script", .{
                .w = 450,
                .h = 100,
            })) {
                std.debug.print("delete texture script\n", .{});
            }
        }
    }
    zgui.endChild();
}
