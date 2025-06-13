const std = @import("std");

pub const WlHeader = packed struct {
    id: u32,
    op: u16,
    size: u16,
};


pub const WaylandConnection = struct {
    socket: std.posix.socket_t,

    pub fn init(allocator: std.mem.Allocator) !WaylandConnection {
        const xdg_runtime_dir = std.posix.getenv("XDG_RUNTIME_DIR") orelse return error.NoXdgRuntime;
        const wayland_display = std.posix.getenv("WAYLAND_DISPLAY") orelse return error.NoWaylandDisplay;
        const socket_path = try std.fs.path.joinZ(allocator, &.{ xdg_runtime_dir, wayland_display });
        const socket = try std.posix.socket(std.posix.system.AF.UNIX, std.posix.system.SOCK.STREAM, 0);
        var addr = std.posix.system.sockaddr.un{
            .path = undefined,
        };
        if (addr.path.len <= socket_path.len) {
            return error.PathToLong;
        }
        @memcpy(addr.path[0..socket_path.len], socket_path);
        try std.posix.connect(socket, @ptrCast(&addr), @sizeOf(@TypeOf(addr)));
        return WaylandConnection{ .socket = socket };
    }
};
