const Platform = @This();
const RawWindow = @import("linux/wayland/wayland.zig");

pub const Window = struct {
    handle: i32,
    raw: RawWindow,
};

pub fn create_window(name: []const u8, width: i32, height: i32) Window {
    return .{ .handle = 1 };
}
