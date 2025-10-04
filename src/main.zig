const __DEBUG__: bool = true;
const std = @import("std");
const TARGET_OS = @import("builtin").os.tag;
const Font = @import("font/font.zig");
const FontAttributes = Font.FontAttributes;
const lhmem = @import("memory/memory.zig");
const Arena = lhmem.Arena;
const base = @import("base/base_types.zig");

extern fn putenv(string: [*:0]const u8) c_int;

pub fn main() !void {
    if (__DEBUG__) {
        if (TARGET_OS == .windows) {
            _ = putenv("VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation;VK_LAYER_KHRONOS_profiles");
        } else {
            _ = putenv("VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation:VK_LAYER_KHRONOS_profiles");
        }
    }

    const a = std.posix.getenv("ZCODER_DEBUG");
    if (a) |b| {
        std.log.info("DEBUG SET {s}", .{b});
    }
}
