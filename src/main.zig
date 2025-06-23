const __DEBUG__: bool = true;
const std = @import("std");
const TARGET_OS = @import("builtin").os.tag;
const zigimg = @import("zigimg");
const Font = @import("font/font.zig");
const GeneratedGlyph = @import("font/glyf.zig").GeneratedGlyph;
const FontAttributes = Font.FontAttributes;
const lhmem = @import("memory/memory.zig");
const Arena = lhmem.Arena;
const lhvk = @import("graphics/lhvk.zig");
const windowing = @import("graphics/win32.zig");
const e = @import("graphics/windowing/events.zig");
const la = @import("lin_alg/la.zig");
const print = std.debug.print;
const draw = @import("graphics/drawing/primitives.zig");
const text = @import("graphics/drawing/text.zig");
const v = @import("graphics/drawing/vertex.zig");
const VertexList = v.VertexList;
const VertexGroup = v.VertexGroup;
const base = @import("base/base_types.zig");
const Rectu32 = base.Rectu32;
const Platform = @import("platform/platform.zig");

extern fn putenv(string: [*:0]const u8) c_int;

pub const Editor = struct {
    graphics_ctx: lhvk.LhvkGraphicsCtx,
    font: FontAttributes,
    window: Platform.Window,
};


fn load_font(app: *Editor, name: []const u8) !void {
    app.font = try Font.load_font(name);
}

pub fn main() !void {
    if (__DEBUG__) {
        if (TARGET_OS == .windows) {
            _ = putenv("VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation;VK_LAYER_KHRONOS_profiles");
        } else {
            _ = putenv("VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation:VK_LAYER_KHRONOS_profiles");
        }
    }
    var app: Editor = undefined;
    app.graphics_ctx.vk_app.arena = lhmem.make_arena(lhmem.MB(10));
    app.graphics_ctx.vk_appdata.arena = lhmem.make_arena(lhmem.MB(10));
    const thr = try std.Thread.spawn(.{}, load_font, .{ &app, "Envy Code R.ttf" });

    app.window = Platform.create_window("name", 600, 400);

    var quit: bool = false;
    var i: usize = 0;
    while (!quit) {
        const frame_arena: Arena = lhmem.make_arena(lhmem.MB(16));
        _ = frame_arena;
        if (i == 10000) {
            quit = true;
        }
        i += 1;
    }
    thr.join();
}
