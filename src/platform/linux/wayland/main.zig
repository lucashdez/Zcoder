const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const f_wayland_connection = @import("wayland_connection.zig");
const f_events = @import("events.zig");
const Display = @import("display.zig").Display;
const Registry = @import("registry.zig").Registry;
const Compositor = @import("compositor.zig").Compositor;
const Surface = @import("surface.zig").Surface;
const WaylandConnection = f_wayland_connection.WaylandConnection;
const WlHeader = f_wayland_connection.WlHeader;
const EventIt = f_events.EventIt;
const EventDataParser = f_events.EventDataParser;

pub const WaylandIdAllocator = struct {
    id: u32 = 3,
    pub fn allocate(self: *WaylandIdAllocator) u32 {
        defer self.id += 1;
        return self.id;
    }
};

const RawWayland = struct {
    compositor: ?Compositor,
    surface: ?Surface,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const wl_connection: WaylandConnection = try WaylandConnection.init(allocator);
    const display = Display.init();
    const registry = try display.getRegistry(wl_connection.socket);
    var compositor: ?Compositor = undefined;
    var raw: RawWayland = undefined;

    var buf: [4096]u8 = undefined;
    const response_l = try std.posix.read(wl_connection.socket, &buf);
    var it = EventIt{ .buf = buf[0..response_l] };

    var ids = WaylandIdAllocator{};

    while (it.next()) |event| {
        if (event.header.id == display.id) {
            try display.handleEvent(event);
        } else if (event.header.id == registry.id) {
            const action = try registry.handleEvent(event);
            compositor = try registry.bind_compositor(wl_connection.socket, action, ids.allocate());
            if (compositor) |c| {
                raw.compositor = c;
            }
        } else {
            print("{any}, {s}\n", .{ event.header, std.mem.trim(u8, event.data, " ") });
        }
    }
    try display.sync(wl_connection.socket, ids.allocate());
    raw.surface = try raw.compositor.?.createSurface(wl_connection.socket, ids.allocate());
    print("{any}, {any}", .{ raw.compositor, raw.surface });
}
