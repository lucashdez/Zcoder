const __DEBUG__: bool = true;
const std = @import("std");
const TARGET_OS = @import("builtin").os.tag;
const Font = @import("font/font.zig");
const FontAttributes = Font.FontAttributes;
const lhmem = @import("memory/memory.zig");
const Arena = lhmem.Arena;
const base = @import("base/base_types.zig");
const Platform = @import("platform/platform.zig");
const logger = @import("base/base.zig");

extern fn putenv(string: [*:0]const u8) c_int;

pub fn main() !void {
    logger.WARN(@src(),"{s}", .{"hello"});
    logger.ERROR(@src(),"{s}", .{"hello"});
    logger.INFO(@src(),"{s}", .{"hello"});
    logger.DEBUG(@src(),"{s}", .{"hello"});
    if (__DEBUG__) {
        if (TARGET_OS == .windows) {
            _ = putenv("VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation;VK_LAYER_KHRONOS_profiles");
        } else {
            _ = putenv("VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation:VK_LAYER_KHRONOS_profiles");
        }
    }
    const platform = Platform.start_platform_layer(); 
    platform.init_window("something", 100, 200);


    const a = std.posix.getenv("ZCODER_DEBUG");
    if (a) |b| {
        std.log.info("DEBUG SET {s}", .{b});
    }
}
