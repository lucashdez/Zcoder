const std = @import("std");
const Surface = @import("surface.zig").Surface;
const WlHeader = @import("wayland_connection.zig").WlHeader;
const assert = std.debug.assert;

const CompositorOp = enum(u16) {
    create_surface = 0,
    create_region = 1,

    fn val(self: *const CompositorOp) u16 {
        return @intFromEnum(self.*);
    }
};

pub const Compositor = struct {
    id: u32,

    pub fn createSurface(
        compositor: *const Compositor,
        socket: std.posix.socket_t,
        new_id: u32,
    ) !Surface {
        const CompositorCreateSurfaceMsg = packed struct {
            header: WlHeader,
            new_id: u32,
        };
        const msg = CompositorCreateSurfaceMsg{
            .header = .{ .id = compositor.id, .op = CompositorOp.create_surface.val(), .size = @sizeOf(CompositorCreateSurfaceMsg) },
            .new_id = new_id,
        };

        // BUG: sometimes the socket is dead, i do not know why
        
        const written = try std.posix.write(socket, std.mem.asBytes(&msg));
        assert(written == @sizeOf(CompositorCreateSurfaceMsg));
        return Surface {.id = new_id};
    }
};
