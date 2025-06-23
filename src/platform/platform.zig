const Platform = @This();
const OS_TAG = @import("builtin").os.tag;
const RawWindow = if (OS_TAG == .windows) @import("windows/win32.zig").RawWindow  else @import("linux/wayland/wayland.zig");

pub const Window = struct
{
    handle: i32,
    raw: RawWindow,
};

pub fn
create_window(name: []const u8, width: i32, height: i32) Window
{
    const raw = RawWindow.init(name, width, height);
    return .{ .handle = 1, .raw = raw };
}
