const OS_TAG = @import("builtin").os.tag;
const pltf = @import("linux/wayland/wayland.zig");

pub const Platform = struct 
{
    init: fn () Platform,
    init_window: fn (state: *Platform, name: []const u8, width: i32, height: i32) void,
    destroy: fn (window: *Platform) void,
};

pub fn start_platform_layer() 
Platform 
{
    return switch (@import("builtin").os.tag) {
        .linux => blk: {
            const wayland = @import("linux/wayland/wayland.zig");
            break :blk wayland.init();
        },
        else => @compileError("Unsupported platform"),
    };
}
